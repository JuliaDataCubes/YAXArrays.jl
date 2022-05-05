# Saving and Loading Datasets and YAXArrays

### Saving a YAXArray to Zarr

One can save any `YAXArray` using the `savecube` function. Simply add a path as an argument and the cube will be saved. 

````@jldoctest
julia> using YAXArrays, Zarr, NetCDF

julia> a = YAXArray(rand(10,20));

julia> f = tempname();

julia> savecube(a,f,driver=:zarr)
YAXArray with the following dimensions
Dim_1               Axis with 10 Elements from 1 to 10
Dim_2               Axis with 20 Elements from 1 to 20
Total size: 1.56 KB
````


If case the pathname ends with ".zarr", the driver argument can be omitted. 

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

If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset>

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

### Creating a Dataset without writing the actual data

Sometimes one merely wants to create a Dataset "Skeleton" on disk and gradually fill it with data.
Here we create Dataset and write only the axis data and array metadata, while no actual array data is
copied:

````@jldoctest
julia> using YAXArrays, Zarr

julia> a = YAXArray(zeros(Union{Missing, Int32},10,20))
YAXArray with the following dimensions
Dim_1               Axis with 10 Elements from 1 to 10
Dim_2               Axis with 20 Elements from 1 to 20
Total size: 800.0 bytes


julia> f = tempname();

julia> r = savecube(a,f,driver=:zarr,skeleton_only=true);

julia> all(ismissing,r[:,:])
true
````

The `skeleton_only` argument is also available for `savedataset`. 

