# # Set chunks

# To determine the chunk size of the array representation on disk, 
# call the `setchunks` function prior to saving.

# ## Chunking YAXArrays

using YAXArrays, Zarr
a = YAXArray(rand(10,20))
a_chunked = setchunks(a, (5,10))
a_chunked.chunks

# And the saved file is also splitted into Chunks.
f = tempname()
savecube(a_chunked, f, backend=:zarr)
Cube(f).chunks

# Alternatively chunk sizes can be given by dimension name, so the following results in the same chunks:

a_chunked = setchunks(a, (Dim_2=10, Dim_1=5))
a_chunked.chunks

# ## Chunking Datasets
# ### Set Chunks by Axis

# Set chunk size for each axis occuring in a dataset. This will be applied to all variables in the dataset:


using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)))
dschunked = setchunks(ds, Dict("Dim_1"=>5, "Dim_2"=>10, "Dim_3"=>2))
Cube(dschunked).chunks

# Saving...

f = tempname()
savedataset(dschunked, path=f,driver=:zarr)

# ### Set chunking by Variable

# The following will set the chunk size for each Variable separately 
# and results in exactly the same chunking as the example above

using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)))
dschunked = setchunks(ds,(x = (5,10), y = Dict("Dim_1"=>5), z = (Dim_1 = 5, Dim_2 = 10, Dim_3 = 2)))
Cube(dschunked).chunks

# saving...

f = tempname()
savedataset(dschunked,path=f,driver=:zarr)

# ### Set chunking for all variables

# The following code snippet only works when all member variables of the dataset have the same shape and sets the output chunks for all arrays. 

using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10,20)), z = YAXArray(rand(10,20)))
dschunked = setchunks(ds,(5,10))
Cube(dschunked).chunks

# saving...

f = tempname()
savedataset(dschunked,path=f,driver=:zarr)