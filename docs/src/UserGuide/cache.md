# Caching YAXArrays

For some applications like interactive plotting of large datasets it can not be avoided that the same data must be accessed several times. In these cases it can be useful to store recently accessed data in a cache. In YAXArrays this can be easily achieved using the `cache` function. For example, if we open a large dataset from a remote source and want to keep data in a cache of size 500MB one can use:

````julia
using YAXArrays, Zarr
ds = open_dataset("path/to/source")
cachesize = 500 #MB
cache(ds,maxsize = cachesize)
````

The above will wrap every array in the dataset into its own cache, where the 500MB are distributed equally across datasets. 
Alternatively individual caches can be applied to single `YAXArray`s

````julia
yax = ds.avariable
cache(yax,maxsize = 1000)
````
