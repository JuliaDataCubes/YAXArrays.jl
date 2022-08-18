# Saving and and Rechunking Datasets and YAXArrays

## Saving 

### Saving a YAXArray to Zarr

One can save any `YAXArray` using the `savecube` function. Simply add a path as an argument and the cube will be saved. 

````@jldoctest
julia> using YAXArrays, Zarr

julia> a = YAXArray(rand(10,20));

julia> f = tempname();

julia> savecube(a,f,driver=:zarr)
YAXArray with the following dimensions
Dim_1               Axis with 10 Elements from 1 to 10
Dim_2               Axis with 20 Elements from 1 to 20
Total size: 1.56 KB
````


If the pathname ends with ".zarr", the driver argument can be omitted. 

### Saving a YAXArray to NetCDF

Saving to NetCDF works exactly the same way. The `driver` argument can be omitted when the filename ends with ".nc"

````@jldoctest
julia> using YAXArrays, Zarr, NetCDF

julia> a = YAXArray(rand(10,20));

julia> f = tempname();

julia> savecube(a,f,driver=:netcdf)
YAXArray with the following dimensions
Dim_1               Axis with 10 Elements from 1 to 10
Dim_2               Axis with 20 Elements from 1 to 20
Total size: 1.56 KB
````

### Saving a Dataset

Saving Datasets can be done using the `savedataset` function.

````@jldoctest saveds
julia> using YAXArrays, Zarr

julia> ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)));

julia> f = tempname();

julia> savedataset(ds,path=f,driver=:zarr)
YAXArray Dataset
Dimensions: 
   Dim_2               Axis with 20 Elements from 1 to 20
   Dim_1               Axis with 10 Elements from 1 to 10
Variables: x y
````

### Overwriting a Dataset

If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset

````@jldoctest saveds
julia> savedataset(ds,path=f,driver=:zarr, overwrite=true)
YAXArray Dataset
Dimensions: 
   Dim_2               Axis with 20 Elements from 1 to 20
   Dim_1               Axis with 10 Elements from 1 to 10
Variables: x y
````

### Appending to a Dataset

New variables can be added to an existing dataset using the `append=true` keyword. 

````@jldoctest
julia> ds2 = Dataset(z = YAXArray(rand(10,20,5)));

julia> savedataset(ds2,path=f,backend=:zarr,append=true);

julia> open_dataset(f, driver=:zarr)
YAXArray Dataset
Dimensions: 
   Dim_2               Axis with 20 Elements from 1 to 20
   Dim_1               Axis with 10 Elements from 1 to 10
   Dim_3               Axis with 5 Elements from 1 to 5
Variables: x z y 
````

### Creating a Datacube without writing the actual data

Sometimes one merely wants to create a datacube  "Skeleton" on disk and gradually fill it with data.
Here we create YAXArray and write only the axis data and array metadata to disk, while no actual array data is
copied:

````@jldoctest
julia> using YAXArrays, Zarr

julia> a = YAXArray(zeros(Union{Missing, Int32},10,20))
YAXArray with the following dimensions
Dim_1               Axis with 10 Elements from 1 to 10
Dim_2               Axis with 20 Elements from 1 to 20
Total size: 800.0 bytes


julia> f = tempname();

julia> r = savecube(a,f,driver=:zarr,skeleton=true);

julia> all(ismissing,r[:,:])
true
````

The `skeleton` argument is also available for `savedataset`. 

## Rechunking

### Saving a YAXArray with user-defined chunks

To determine the chunk size of the array representation on disk, call the `setchunks` function prior to saving:

````@jldoctest chunks1
julia> using YAXArrays, Zarr, NetCDF

julia> a = YAXArray(rand(10,20));

julia> f = tempname();

julia> a_chunked = setchunks(a,(5,10));

julia> savecube(a_chunked,f,backend=:zarr);

julia> Cube(f).chunks
2×2 DiskArrays.GridChunks{2}:
 (1:5, 1:10)   (1:5, 11:20)
 (6:10, 1:10)  (6:10, 11:20)
````

Alternatively chunk sizes can be given by dimension name, so the following results in the same chunks:

````@jldoctest chunks1
a_chunked = setchunks(a,(Dim_2=10, Dim_1=5));
````

## Rechunking Datasets

### Set Chunks by Axis

Set chunk size for each axis occuring in a dataset. This will be applied to all variables in the dataset:

````@jldoctest
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)));
dschunked = setchunks(ds,Dict("Dim_1"=>5, "Dim_2"=>10, "Dim_3"=>2));
f = tempname();
savedataset(dschunked,path=f,driver=:zarr)
````

### Set chunking by Variable

The following will set the chunk size for each Variable separately and results in exactly the same chunking as the example above

````@jldoctest
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)));
dschunked = setchunks(ds,(x = (5,10), y = Dict("Dim_1"=>5), z = (Dim_1 = 5, Dim_2 = 10, Dim_3 = 2)));
f = tempname();
savedataset(dschunked,path=f,driver=:zarr)
````

### Set chunking for all variables

The following code snippet only works when all member variables of the dataset have the same shape and sets the output chunks for all arrays. 

````@jldoctest
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10,20)), z = YAXArray(rand(10,20)));
dschunked = setchunks(ds,(5,10));
f = tempname();
savedataset(dschunked,path=f,driver=:zarr)
````