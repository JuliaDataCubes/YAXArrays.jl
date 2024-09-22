# Write YAXArrays and Datasets

Create an example Dataset:

````@example write
using YAXArrays
using NetCDF
using Downloads: download

path = download("https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc", "example.nc")
ds = open_dataset(path)
````

## Write Zarr

Save a single YAXArray to a directory:

````@example write
using Zarr
savecube(ds.tos, "tos.zarr", driver=:zarr)
nothing # hide
````

Save an entire Dataset to a directory:

````@example write
savedataset(ds, path="ds.zarr", driver=:zarr)
nothing # hide
````
### zarr compression
Save a dataset to Zarr format with compression:

````@example write
n = 9 # compression level, number between 0 (no compression) and 9 (max compression)
compression = Zarr.BloscCompressor(; clevel=n)

savedataset(ds; path="ds_c.zarr", driver=:zarr, compressor=compression)
nothing # hide
````

More on [Zarr Compressors](https://juliaio.github.io/Zarr.jl/latest/reference/#Compressors). Also, if you use this option and don't notice a significant improvement, please feel free to open an issue or start a discussion. 

## Write NetCDF

Save a single YAXArray to a directory:

````@example write
using NetCDF
savecube(ds.tos, "tos.nc", driver=:netcdf)
nothing # hide
````

Save an entire Dataset to a directory:

````@example write
savedataset(ds, path="ds.nc", driver=:netcdf)
nothing # hide
````

### netcdf compression
Save a dataset to NetCDF format with compression:

````@example write
n = 7 # compression level, number between 0 (no compression) and 9 (max compression)
savedataset(ds, path="ds_c.nc", driver=:netcdf, compress=n)
nothing # hide
````

Comparing it to the default saved file

````@example write
ds_info = stat("ds.nc")
ds_c_info = stat("ds_c.nc")
println("File size: ", "default: ", ds_info.size, " bytes", ", compress: ", ds_c_info.size, " bytes")
````

## Overwrite a Dataset    
If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset

````@example write
savedataset(ds, path="ds.zarr", driver=:zarr, overwrite=true)
nothing # hide
````

::: danger

Again, setting `overwrite` will delete all your previous saved data.

:::

Look at the doc string for more information

````@docs
savedataset
````

## Append to a Dataset

New variables can be added to an existing dataset using the `append=true` keyword. 

````@example write
ds2 = Dataset(z = YAXArray(rand(10,20,5)))
savedataset(ds2, path="ds.zarr", backend=:zarr, append=true)
nothing # hide
````

````@ansi write
open_dataset("ds.zarr", driver=:zarr)
````

## Save Skeleton
Sometimes one merely wants to create a datacube  "Skeleton" on disk and gradually fill it with data. Here we make use of `FillArrays` to create a `YAXArray` and write only the axis data and array metadata to disk, while no actual array data is copied:

````@example write
using YAXArrays, Zarr, FillArrays
````

create the `Zeros` array

````@ansi write
a = YAXArray(Zeros(Union{Missing, Float32},  5, 4, 5))
````

Now, save to disk with

````@example write
r = savecube(a, "skeleton.zarr", layername="skeleton", driver=:zarr, skeleton=true, overwrite=true)
nothing # hide
````

::: warning

`overwrite=true` will delete your previous `.zarr` file before creating a new one.

:::

Note also that if `layername="skeleton"` is not provided then the `default name` for the cube variable will be `layer`.

Now, we check that all the values are `missing`

````@example write
all(ismissing, r[:,:,:])
````

If using `FillArrays` is not possible, using the `zeros` function works as well, though it does allocate the array in memory.

::: info

The `skeleton` argument is also available for `savedataset`. 

:::

Using the toy array defined above we can do 

````@example write
ds = Dataset(skeleton=a) # skeleton will the variable name
````

````@example write
ds_s = savedataset(ds, path="skeleton.zarr", driver=:zarr, skeleton=true, overwrite=true)
nothing # hide
````

## Update values of `dataset`

Now, we show how to start updating the array values. In order to do it we need to open the dataset first with writing `w` rights as follows:

````@example write
ds_open = zopen("skeleton.zarr", "w")
ds_array = ds_open["skeleton"]
````

and then we simply update values by indexing them where necessary

````@example write
ds_array[:,:,1] = rand(Float32, 5, 4) # this will update values directly into disk!
````

we can verify is this working by loading again directly from disk

````@example write
ds_open = open_dataset("skeleton.zarr")
ds_array = ds_open["skeleton"]
ds_array.data[:,:,1]
````

indeed, those entries had been updated.

