
# Chunk YAXArrays {#Chunk-YAXArrays}
> 
> [!IMPORTANT] Thinking about chunking is important when it comes to analyzing your data, because in most situations this will not fit into memory, hence having the fastest read access to it is crucial for your workflows. For example, for geo-spatial data do you want fast access on time or space, or... think about it.
> 


To determine the chunk size of the array representation on disk,  call the `setchunks` function prior to saving.

## Chunking YAXArrays {#Chunking-YAXArrays}

```julia
using YAXArrays, Zarr
a = YAXArray(rand(10,20))
a_chunked = setchunks(a, (5,10))
a_chunked.chunks
```


```
2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
 (1:5, 1:10)   (1:5, 11:20)
 (6:10, 1:10)  (6:10, 11:20)
```


And the saved file is also splitted into Chunks.

```julia
f = tempname()
savecube(a_chunked, f, backend=:zarr)
Cube(f).chunks
```


```
2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
 (1:5, 1:10)   (1:5, 11:20)
 (6:10, 1:10)  (6:10, 11:20)
```


Alternatively chunk sizes can be given by dimension name, so the following results in the same chunks:

```julia
a_chunked = setchunks(a, (Dim_2=10, Dim_1=5))
a_chunked.chunks
```


```
2×2 DiskArrays.GridChunks{2, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
 (1:5, 1:10)   (1:5, 11:20)
 (6:10, 1:10)  (6:10, 11:20)
```


## Chunking Datasets {#Chunking-Datasets}

Setchunks can also be applied to a `Dataset`.

### Set Chunks by Axis {#Set-Chunks-by-Axis}

Set chunk size for each axis occuring in a `Dataset`. This will be applied to all variables in the dataset:

```julia
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)))
dschunked = setchunks(ds, Dict("Dim_1"=>5, "Dim_2"=>10, "Dim_3"=>2))
Cube(dschunked).chunks
```


```
2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
[:, :, 1] =
 (1:5, 1:10, 1:2)   (1:5, 11:20, 1:2)
 (6:10, 1:10, 1:2)  (6:10, 11:20, 1:2)

[:, :, 2] =
 (1:5, 1:10, 3:4)   (1:5, 11:20, 3:4)
 (6:10, 1:10, 3:4)  (6:10, 11:20, 3:4)

[:, :, 3] =
 (1:5, 1:10, 5:5)   (1:5, 11:20, 5:5)
 (6:10, 1:10, 5:5)  (6:10, 11:20, 5:5)
```


Saving...

```julia
f = tempname()
savedataset(dschunked, path=f, driver=:zarr)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points)

Variables: 
y

Variables with additional axes:
  Additional Axes: 
  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points,
  → Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points)
  Variables: 
  z

  Additional Axes: 
  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)
  Variables: 
  x


```


### Set chunking by Variable {#Set-chunking-by-Variable}

The following will set the chunk size for each Variable separately  and results in exactly the same chunking as the example above

```julia
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10)), z = YAXArray(rand(10,20,5)))
dschunked = setchunks(ds,(x = (5,10), y = Dict("Dim_1"=>5), z = (Dim_1 = 5, Dim_2 = 10, Dim_3 = 2)))
Cube(dschunked).chunks
```


```
2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
[:, :, 1] =
 (1:5, 1:10, 1:2)   (1:5, 11:20, 1:2)
 (6:10, 1:10, 1:2)  (6:10, 11:20, 1:2)

[:, :, 2] =
 (1:5, 1:10, 3:4)   (1:5, 11:20, 3:4)
 (6:10, 1:10, 3:4)  (6:10, 11:20, 3:4)

[:, :, 3] =
 (1:5, 1:10, 5:5)   (1:5, 11:20, 5:5)
 (6:10, 1:10, 5:5)  (6:10, 11:20, 5:5)
```


saving...

```julia
f = tempname()
savedataset(dschunked, path=f, driver=:zarr)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points)

Variables: 
y

Variables with additional axes:
  Additional Axes: 
  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points,
  → Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points)
  Variables: 
  z

  Additional Axes: 
  (↓ Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)
  Variables: 
  x


```


### Set chunking for all variables {#Set-chunking-for-all-variables}

The following code snippet only works when all member variables of the dataset have the same shape and sets the output chunks for all arrays. 

```julia
using YAXArrays, Zarr
ds = Dataset(x = YAXArray(rand(10,20)), y = YAXArray(rand(10,20)), z = YAXArray(rand(10,20)))
dschunked = setchunks(ds,(5,10))
Cube(dschunked).chunks
```


```
2×2×3 DiskArrays.GridChunks{3, Tuple{DiskArrays.RegularChunks, DiskArrays.RegularChunks, DiskArrays.RegularChunks}}:
[:, :, 1] =
 (1:5, 1:10, 1:1)   (1:5, 11:20, 1:1)
 (6:10, 1:10, 1:1)  (6:10, 11:20, 1:1)

[:, :, 2] =
 (1:5, 1:10, 2:2)   (1:5, 11:20, 2:2)
 (6:10, 1:10, 2:2)  (6:10, 11:20, 2:2)

[:, :, 3] =
 (1:5, 1:10, 3:3)   (1:5, 11:20, 3:3)
 (6:10, 1:10, 3:3)  (6:10, 11:20, 3:3)
```


saving...

```julia
f = tempname()
savedataset(dschunked, path=f, driver=:zarr)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points,
  → Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points)

Variables: 
x, y, z


```


Suggestions on how to improve or add to these examples is welcome.
