# Saving YAXArrays and Datasets

Is possible to save datasets and `YAXArray` directly to `zarr` files.

## Saving a YAXArray to Zarr

One can save any `YAXArray` using the `savecube` function. 
Simply add a path as an argument and the cube will be saved. 

````@example saveYAX
using YAXArrays, Zarr
a = YAXArray(rand(10,20))
savecube(a, "our_yax.zarr", driver=:zarr)
nothing # hide
````


## Saving a YAXArray to NetCDF

Saving to NetCDF works exactly the same way:

````@example saveYAX
using YAXArrays, Zarr, NetCDF
a = YAXArray(rand(10,20))
savecube(a, "our_yax.nc", driver=:netcdf)
nothing # hide
````

## Saving a Dataset

Saving Datasets can be done using the `savedataset` function.

````@example saveDataset
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)))
f = "our_dataset.zarr"
savedataset(ds, path=f, driver=:zarr)
nothing # hide
````

## Overwriting a Dataset    
If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset

````@example saveDataset
savedataset(ds, path=f, driver=:zarr, overwrite=true)
nothing # hide
````

::: danger

Again, setting `overwrite` will delete all your previous saved data.

:::

Look at the doc string for more information

````@docs
savedataset
````

## Appending to a Dataset

New variables can be added to an existing dataset using the `append=true` keyword. 

````@example saveDataset
ds2 = Dataset(z = YAXArray(rand(10,20,5)))
savedataset(ds2, path=f, backend=:zarr, append=true)
nothing # hide
````

````@ansi saveDataset
open_dataset(f, driver=:zarr)
````

## Datacube Skeleton without the actual data
Sometimes one merely wants to create a datacube  "Skeleton" on disk and gradually fill it with data. Here we make use of `FillArrays` to create a `YAXArray` and write only the axis data and array metadata to disk, while no actual array data is copied:

````@example saveDataset
using YAXArrays, Zarr, FillArrays
````

create the `Zeros` array

````@ansi saveDataset
a = YAXArray(Zeros(Union{Missing, Int32}, 10, 20))
````

and save them as

````@example saveDataset
r = savecube(a, "skeleton.zarr", driver=:zarr, skeleton=true)
nothing # hide
````

and check that all the values are `missing`

````@example saveDataset
all(ismissing,r[:,:])
````

If using `FillArrays` is not possible, using the `zeros` function works as well, though it does allocate the array in memory.

::: info

The `skeleton` argument is also available for `savedataset`. 

:::
