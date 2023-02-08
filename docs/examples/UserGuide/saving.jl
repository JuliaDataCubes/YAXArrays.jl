# # Saving YAXArrays and Datasets

# Is possible to save datasets and YAXArray directly to zarr files.

# ## Saving a YAXArray to Zarr
# One can save any `YAXArray` using the `savecube` function. 
# Simply add a path as an argument and the cube will be saved. 

using YAXArrays, Zarr
a = YAXArray(rand(10,20))
f = tempname()
savecube(a,f,driver=:zarr)

# ## Saving a YAXArray to NetCDF
# Saving to NetCDF works exactly the same way.

using YAXArrays, Zarr, NetCDF
a = YAXArray(rand(10,20))
f = tempname()
savecube(a,f,driver=:netcdf)

# ## Saving a Dataset

# Saving Datasets can be done using the `savedataset` function.
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)));
f = tempname();
savedataset(ds,path=f,driver=:zarr)
# ## Overwriting a Dataset    
# If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset
savedataset(ds,path=f,driver=:zarr, overwrite=true)

# Look at the docs for more information

Docs.doc(savedataset) # hide

# ## Appending to a Dataset
# New variables can be added to an existing dataset using the `append=true` keyword. 
ds2 = Dataset(z = YAXArray(rand(10,20,5)))
savedataset(ds2, path=f,backend=:zarr,append=true)
open_dataset(f, driver=:zarr)
    
# ## Datacube Skeleton without the actual data
# Sometimes one merely wants to create a datacube  "Skeleton" on disk and gradually fill it with data.
# Here we create YAXArray and write only the axis data and array metadata to disk,
# while no actual array data is copied:
    
using YAXArrays, Zarr
a = YAXArray(zeros(Union{Missing, Int32},10,20))
f = tempname();
r = savecube(a,f,driver=:zarr,skeleton=true);
all(ismissing,r[:,:])

# The `skeleton` argument is also available for `savedataset`. 