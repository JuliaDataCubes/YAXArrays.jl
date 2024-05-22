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
a = YAXArray(Zeros(Union{Missing, Int32}, 10, 20))
````

and save them as

````@example write
r = savecube(a, "skeleton.zarr", driver=:zarr, skeleton=true)
nothing # hide
````

and check that all the values are `missing`

````@example write
all(ismissing,r[:,:])
````

If using `FillArrays` is not possible, using the `zeros` function works as well, though it does allocate the array in memory.

::: info

The `skeleton` argument is also available for `savedataset`. 

:::

