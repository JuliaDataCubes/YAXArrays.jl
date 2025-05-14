
# API Reference {#API-Reference}

This section describes all available functions of this package.

## Public API {#Public-API}


<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.getAxis-Tuple{Any, Any}' href='#YAXArrays.getAxis-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.getAxis</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
getAxis(desc, c)
```


Given an Axis description and a cube, returns the corresponding axis of the cube. The Axis description can be:
- the name as a string or symbol.
  
- an Axis object
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/helpers.jl#L124-L131" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes' href='#YAXArrays.Cubes'><span class="jlbinding">YAXArrays.Cubes</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



The functions provided by YAXArrays are supposed to work on different types of cubes. This module defines the interface for all Data types that


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L1-L4" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.YAXArray' href='#YAXArrays.Cubes.YAXArray'><span class="jlbinding">YAXArrays.Cubes.YAXArray</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
YAXArray{T,N}
```


An array labelled with named axes that have values associated with them. It can wrap normal arrays or, more typically DiskArrays.

**Fields**
- `axes`: `Tuple` of Dimensions containing the Axes of the Cube
  
- `data`: length(axes)-dimensional array which holds the data, this can be a lazy DiskArray
  
- `properties`: Metadata properties describing the content of the data
  
- `chunks`: Representation of the chunking of the data
  
- `cleaner`: Cleaner objects to track which objects to tidy up when the YAXArray goes out of scope
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L84-L93" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.caxes' href='#YAXArrays.Cubes.caxes'><span class="jlbinding">YAXArrays.Cubes.caxes</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



Returns the axes of a Cube


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L27" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.caxes-Tuple{DimensionalData.Dimensions.Dimension}' href='#YAXArrays.Cubes.caxes-Tuple{DimensionalData.Dimensions.Dimension}'><span class="jlbinding">YAXArrays.Cubes.caxes</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
caxes
```


Embeds  Cube inside a new Cube


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L221-L225" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.concatenatecubes-Tuple{Any, DimensionalData.Dimensions.Dimension}' href='#YAXArrays.Cubes.concatenatecubes-Tuple{Any, DimensionalData.Dimensions.Dimension}'><span class="jlbinding">YAXArrays.Cubes.concatenatecubes</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
function concatenateCubes(cubelist, cataxis::CategoricalAxis)
```


Concatenates a vector of datacubes that have identical axes to a new single cube along the new axis `cataxis`


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/TransformedCubes.jl#L29-L34" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.readcubedata-Tuple{Any}' href='#YAXArrays.Cubes.readcubedata-Tuple{Any}'><span class="jlbinding">YAXArrays.Cubes.readcubedata</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
readcubedata(cube)
```


Given any array implementing the YAXArray interface it returns an in-memory [`YAXArray`](/UserGuide/types#YAXArray) from it.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L228-L232" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.setchunks-Tuple{YAXArray, Any}' href='#YAXArrays.Cubes.setchunks-Tuple{YAXArray, Any}'><span class="jlbinding">YAXArrays.Cubes.setchunks</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
setchunks(c::YAXArray,chunks)
```


Resets the chunks of a YAXArray and returns a new YAXArray. Note that this will not change the chunking of the underlying data itself,  it will just make the data &quot;look&quot; like it had a different chunking. If you need a persistent on-disk representation of this chunking, use `savecube` on the resulting array. The `chunks` argument can take one of the following forms:
- a `DiskArrays.GridChunks` object
  
- a tuple specifying the chunk size along each dimension
  
- an AbstractDict or NamedTuple mapping one or more axis names to chunk sizes
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L258-L269" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.subsetcube' href='#YAXArrays.Cubes.subsetcube'><span class="jlbinding">YAXArrays.Cubes.subsetcube</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



This function calculates a subset of a cube&#39;s data


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L22-L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.InDims' href='#YAXArrays.DAT.InDims'><span class="jlbinding">YAXArrays.DAT.InDims</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
InDims(axisdesc...;...)
```


Creates a description of an Input Data Cube for cube operations. Takes a single   or multiple axis descriptions as first arguments. Alternatively a MovingWindow(@ref) struct can be passed to include   neighbour slices of one or more axes in the computation.    Axes can be specified by their   name (String), through an Axis type, or by passing a concrete axis.

**Keyword arguments**
- `artype` how shall the array be represented in the inner function. Defaults to `Array`, alternatives are `DataFrame` or `AsAxisArray`
  
- `filter` define some filter to skip the computation, e.g. when all values are missing. Defaults to   `AllMissing()`, possible values are `AnyMissing()`, `AnyOcean()`, `StdZero()`, `NValid(n)`   (for at least n non-missing elements). It is also possible to provide a custom one-argument function   that takes the array and returns `true` if the compuation shall be skipped and `false` otherwise.
  
- `window_oob_value` if one of the input dimensions is a MowingWindow, this value will be used to fill out-of-bounds areas
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/registration.jl#L58-L75" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.MovingWindow' href='#YAXArrays.DAT.MovingWindow'><span class="jlbinding">YAXArrays.DAT.MovingWindow</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MovingWindow(desc, pre, after)
```


Constructs a `MovingWindow` object to be passed to an `InDims` constructor to define that the axis in `desc` shall participate in the inner function (i.e. shall be looped over), but inside the inner function `pre` values before and `after` values after the center value will be passed as well. 

For example passing `MovingWindow("Time", 2, 0)` will loop over the time axis and  always pass the current time step plus the 2 previous steps. So in the inner function the array will have an additional dimension of size 3.    


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/registration.jl#L8-L19" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.OutDims-Tuple' href='#YAXArrays.DAT.OutDims-Tuple'><span class="jlbinding">YAXArrays.DAT.OutDims</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
OutDims(axisdesc;...)
```


Creates a description of an Output Data Cube for cube operations. Takes a single   or a Vector/Tuple of axes as first argument. Axes can be specified by their   name (String), through an Axis type, or by passing a concrete axis.
- `axisdesc`: List of input axis names
  
- `backend` : specifies the dataset backend to write data to, must be either :auto or a key in `YAXArrayBase.backendlist`
  
- `update` : specifies wether the function operates inplace or if an output is returned
  
- `artype` : specifies the Array type inside the inner function that is mapped over
  
- `chunksize`: A Dict specifying the chunksizes for the output dimensions of the cube, or `:input` to copy chunksizes from input cube axes or `:max` to not chunk the inner dimensions
  
- `outtype`: force the output type to a specific type, defaults to `Any` which means that the element type of the first input cube is used
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/registration.jl#L110-L123" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.CubeTable-Tuple{}' href='#YAXArrays.DAT.CubeTable-Tuple{}'><span class="jlbinding">YAXArrays.DAT.CubeTable</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
CubeTable()
```


Function to turn a DataCube object into an iterable table. Takes a list of as arguments, specified as a `name=cube` expression. For example `CubeTable(data=cube1,country=cube2)` would generate a Table with the entries `data` and `country`, where `data` contains the values of `cube1` and `country` the values of `cube2`. The cubes are matched and broadcasted along their axes like in `mapCube`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/dciterators.jl#L127-L135" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.cubefittable-Tuple{Any, Any, Any}' href='#YAXArrays.DAT.cubefittable-Tuple{Any, Any, Any}'><span class="jlbinding">YAXArrays.DAT.cubefittable</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
cubefittable(tab,o,fitsym;post=getpostfunction(o),kwargs...)
```


Executes [`fittable`](/api#YAXArrays.DAT.fittable-Tuple{YAXArrays.DAT.CubeIterator,%20Any,%20Any}) on the [`CubeTable`](/api#YAXArrays.DAT.CubeTable-Tuple{}) `tab` with the (Weighted-)OnlineStat `o`, looping through the values specified by `fitsym`. Finally, writes the results from the `TableAggregator` to an output data cube.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/tablestats.jl#L317-L323" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.fittable-Tuple{YAXArrays.DAT.CubeIterator, Any, Any}' href='#YAXArrays.DAT.fittable-Tuple{YAXArrays.DAT.CubeIterator, Any, Any}'><span class="jlbinding">YAXArrays.DAT.fittable</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fittable(tab,o,fitsym;by=(),weight=nothing)
```


Loops through an iterable table `tab` and thereby fitting an OnlineStat `o` with the values specified through `fitsym`. Optionally one can specify a field (or tuple) to group by. Any groupby specifier can either be a symbol denoting the entry to group by or an anynymous function calculating the group from a table row.

For example the following would caluclate a weighted mean over a cube weighted by grid cell area and grouped by country and month:

```julia
fittable(iter,WeightedMean,:tair,weight=(i->abs(cosd(i.lat))),by=(i->month(i.time),:country))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/tablestats.jl#L233-L247" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.mapCube-Tuple{Function, Dataset, Vararg{Any}}' href='#YAXArrays.DAT.mapCube-Tuple{Function, Dataset, Vararg{Any}}'><span class="jlbinding">YAXArrays.DAT.mapCube</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
mapCube(fun, cube, addargs...;kwargs...)
```


Map a given function `fun` over slices of all cubes of the dataset `ds`.  Use InDims to discribe the input dimensions and OutDims to describe the output dimensions of the function.

For Datasets, only one output cube can be specified. In contrast to the mapCube function for cubes, additional arguments for the inner function should be set as keyword arguments.

For the specific keyword arguments see the docstring of the mapCube function for cubes.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L315-L325" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.mapCube-Tuple{Function, Tuple, Vararg{Any}}' href='#YAXArrays.DAT.mapCube-Tuple{Function, Tuple, Vararg{Any}}'><span class="jlbinding">YAXArrays.DAT.mapCube</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
mapCube(fun, cube, addargs...;kwargs...)
```


Map a given function `fun` over slices of the data cube `cube`.      The additional arguments `addargs` will be forwarded to the inner function `fun`.     Use InDims to discribe the input dimensions and OutDims to describe the output dimensions of the function.

**Keyword arguments**
- `max_cache=YAXDefaults.max_cache` Float64 maximum size of blocks that are read into memory in bits e.g. `max_cache=5.0e8`. Or String. e.g. `max_cache="10MB"` or `max_cache=1GB` defaults to approx 10Mb.
  
- `indims::InDims` List of input cube descriptors of type [`InDims`](/api#YAXArrays.DAT.InDims) for each input data cube.
  
- `outdims::OutDims` List of output cube descriptors of type [`OutDims`](/api#YAXArrays.DAT.OutDims-Tuple) for each output cube.
  
- `inplace` does the function write to an output array inplace or return a single value&gt; defaults to `true`
  
- `ispar` boolean to determine if parallelisation should be applied, defaults to `true` if workers are available.
  
- `showprog` boolean indicating if a ProgressMeter shall be shown
  
- `include_loopvars` boolean to indicate if the varoables looped over should be added as function arguments
  
- `nthreads` number of threads for the computation, defaults to Threads.nthreads for every worker.
  
- `loopchunksize` determines the chunk sizes of variables which are looped over, a dict
  
- `kwargs` additional keyword arguments are passed to the inner function
  

The first argument is always the function to be applied, the second is the input cube or a tuple of input cubes if needed.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L382-L403" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.Dataset' href='#YAXArrays.Datasets.Dataset'><span class="jlbinding">YAXArrays.Datasets.Dataset</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Dataset object which stores an `OrderedDict` of YAXArrays with Symbol keys. A dictionary of CubeAxes and a Dictionary of general properties. A dictionary can hold cubes with differing axes. But it will share the common axes between the subcubes.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L19-L23" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.Dataset-Tuple{}' href='#YAXArrays.Datasets.Dataset-Tuple{}'><span class="jlbinding">YAXArrays.Datasets.Dataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
Dataset(; properties = Dict{String,Any}, cubes...)
```


Construct a YAXArray Dataset with global attributes `properties` a and a list of named YAXArrays cubes...


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L29-L33" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.Cube-Tuple{Dataset}' href='#YAXArrays.Datasets.Cube-Tuple{Dataset}'><span class="jlbinding">YAXArrays.Datasets.Cube</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
Cube(ds::Dataset; joinname="Variables")
```


Construct a single YAXArray from the dataset `ds` by concatenating the cubes in the datset on the `joinname` dimension.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L487-L491" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.open_dataset-Tuple{Any}' href='#YAXArrays.Datasets.open_dataset-Tuple{Any}'><span class="jlbinding">YAXArrays.Datasets.open_dataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
open_dataset(g; skip_keys=(), driver=:all)
```


Open the dataset at `g` with the given `driver`. The default driver will search for available drivers and tries to detect the useable driver from the filename extension.

**Keyword arguments**
- `skip_keys` are passed as symbols, i.e., `skip_keys = (:a, :b)`
  
- `driver=:all`, common options are `:netcdf` or `:zarr`.
  

Example:

```julia
ds = open_dataset(f, driver=:zarr, skip_keys = (:c,))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L420-L436" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.open_mfdataset-Tuple{DimensionalData.DimVector{var"#s34", D, R, A} where {var"#s34"<:Union{Missing, AbstractString}, D<:Tuple, R<:Tuple, A<:AbstractVector{var"#s34"}}}' href='#YAXArrays.Datasets.open_mfdataset-Tuple{DimensionalData.DimVector{var"#s34", D, R, A} where {var"#s34"<:Union{Missing, AbstractString}, D<:Tuple, R<:Tuple, A<:AbstractVector{var"#s34"}}}'><span class="jlbinding">YAXArrays.Datasets.open_mfdataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
open_mfdataset(files::DD.DimVector{<:AbstractString}; kwargs...)
```


Opens and concatenates a list of dataset paths along the dimension specified in `files`. 

This method can be used when the generic glob-based version of open_mfdataset fails or is too slow.  For example, to concatenate a list of annual NetCDF files along the `time` dimension,  one can use:

```julia
files = ["1990.nc","1991.nc","1992.nc"]
open_mfdataset(DD.DimArray(files, YAX.time()))
```


alternatively, if the dimension to concatenate along does not exist yet, the  dimension provided in the input arg is used:

```julia
files = ["a.nc", "b.nc", "c.nc"]
open_mfdataset(DD.DimArray(files, DD.Dim{:NewDim}(["a","b","c"])))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L377-L399" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.savecube-Tuple{Any, AbstractString}' href='#YAXArrays.Datasets.savecube-Tuple{Any, AbstractString}'><span class="jlbinding">YAXArrays.Datasets.savecube</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
savecube(cube,name::String)
```


Save a [`YAXArray`](/UserGuide/types#YAXArray) to the `path`.

**Extended Help**

The keyword arguments are:
- `name`:
  
- `datasetaxis="Variables"` special treatment of a categorical axis that gets written into separate zarr arrays
  
- `max_cache`: The number of bits that are used as cache for the data handling.
  
- `backend`: The backend, that is used to save the data. Falls back to searching the backend according to the extension of the path.
  
- `driver`: The same setting as `backend`.
  
- `overwrite::Bool=false` overwrite cube if it already exists
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L750-L767" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.savedataset-Tuple{Dataset}' href='#YAXArrays.Datasets.savedataset-Tuple{Dataset}'><span class="jlbinding">YAXArrays.Datasets.savedataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
savedataset(ds::Dataset; path= "", persist=nothing, overwrite=false, append=false, skeleton=false, backend=:all, driver=backend, max_cache=5e8, writefac=4.0)
```


Saves a Dataset into a file at `path` with the format given by `driver`, i.e., `driver=:netcdf` or `driver=:zarr`.

::: warning Warning

`overwrite=true`, deletes ALL your data and it will create a new file.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L662-L670" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.to_dataset-Tuple{Any}' href='#YAXArrays.Datasets.to_dataset-Tuple{Any}'><span class="jlbinding">YAXArrays.Datasets.to_dataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
to_dataset(c;datasetaxis = "Variables", layername = "layer")
```


Convert a Data Cube into a Dataset. It is possible to treat one of the Cube&#39;s axes as a `datasetaxis` i.e. the cube will be split into different parts that become variables in the Dataset. If no such axis is specified or found, there will only be a single variable in the dataset with the name `layername`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L46-L54" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Xmap.MovingIntervals' href='#YAXArrays.Xmap.MovingIntervals'><span class="jlbinding">YAXArrays.Xmap.MovingIntervals</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MovingIntervals{T, O, L, R}
```


A type representing a collection of intervals that can &quot;move&quot; based on specified offsets.  Each interval is defined by a starting point (`i1`), an ending point (`i2`), and a set of offsets  that determine the positions of the intervals.

**Fields**
- `i1::T`: The starting point of the base interval.
  
- `i2::T`: The ending point of the base interval.
  
- `offsets::O`: A collection of offsets that shift the base interval to generate the moving intervals.
  

**Type Parameters**
- `T`: The type of the interval bounds (`i1` and `i2`).
  
- `O`: The type of the offsets collection.
  
- `L`: The left bound type of the interval (e.g., `:open` or `:closed`).
  
- `R`: The right bound type of the interval (e.g., `:open` or `:closed`).
  

**Usage**

`MovingIntervals` is typically used to create a series of intervals that are shifted by the specified offsets.  It supports both array-based and scalar-based definitions for interval bounds and offsets.

**Example**

```julia

**Create moving intervals with array-based left bounds**

left_bounds = [1, 2, 3] width = 2 intervals = MovingIntervals(:open, :closed; left=left_bounds, width=width)

**Access the first interval**

first_interval = intervals[1]  # Interval(1, 3)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/xmap.jl#L78-L109" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Xmap.XFunction-Tuple{Function}' href='#YAXArrays.Xmap.XFunction-Tuple{Function}'><span class="jlbinding">YAXArrays.Xmap.XFunction</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
XFunction(f::Function; outputs = XOutput(), inputs = (),inplace=true)
```


Wraps any Julia function into an XFunction. The result will be callable as a normal Julia  function. However, when broadcasting over the resulting function, the normal broadcast machinery will be skipped and `xmap` functionality will be used for lazy broadcasting of `AbstractDimArrays`  instead.

**Arguments**

`f`: function to be wrapped

**Keyword arguments**

`outputs`: either an `XOutput` or tuple of `XOutput` describing dimensions of the output array that `f` operates on `inputs`: currently not used (yet) `inplace`: set to `false` if `f` is not defined as an inplace function, i.e. it does not write results into its first argument


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/xmap.jl#L326-L343" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Xmap.compute_to_zarr-Tuple{Any, Any}' href='#YAXArrays.Xmap.compute_to_zarr-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.Xmap.compute_to_zarr</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
compute_to_zarr(ods, path; max_cache=5e8, overwrite=false)
```


Computes the YAXArrays dataset `ods` and saves it to a Zarr dataset at `path`.

**Arguments**
- `ods`: The YAXArrays dataset to compute.
  
- `path`: The path to save the Zarr dataset to.
  

**Keywords**
- `max_cache`: The maximum amount of data to cache in memory while computing the dataset.
  
- `overwrite`: Whether to overwrite the dataset at `path` if it already exists.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/xmap.jl#L364-L376" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Internal API {#Internal-API}
<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.YAXDefaults' href='#YAXArrays.YAXDefaults'><span class="jlbinding">YAXArrays.YAXDefaults</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



Default configuration for YAXArrays, has the following fields:
- `workdir[]::String = "./"` The default location for temporary cubes.
  
- `recal[]::Bool = false` set to true if you want `@loadOrGenerate` to always recalculate the results.
  
- `chunksize[]::Any = :input` Set the default output chunksize.
  
- `max_cache[]::Float64 = 1e8` The maximum cache used by mapCube.
  
- `cubedir[]::""` the default location for `Cube()` without an argument.
  
- `subsetextensions::Array{Any} = []` List of registered functions, that convert subsetting input into dimension boundaries. 
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/YAXArrays.jl#L3-L12" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.findAxis-Tuple{Any, Any}' href='#YAXArrays.findAxis-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.findAxis</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
findAxis(desc, c)
```


Internal function

**Extended Help**

```
Given an Axis description and a cube return the index of the Axis.
```


The Axis description can be:
- the name as a string or symbol.
  
- an Axis object
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/helpers.jl#L30-L39" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.getOutAxis-NTuple{5, Any}' href='#YAXArrays.getOutAxis-NTuple{5, Any}'><span class="jlbinding">YAXArrays.getOutAxis</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
getOutAxis
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/helpers.jl#L75-L77" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.get_descriptor-Tuple{String}' href='#YAXArrays.get_descriptor-Tuple{String}'><span class="jlbinding">YAXArrays.get_descriptor</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
get_descriptor(a)
```


Get the descriptor of an Axis.  This is used to dispatch on the descriptor. 


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/helpers.jl#L17-L22" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.match_axis-Tuple{YAXArrays.ByName, Any}' href='#YAXArrays.match_axis-Tuple{YAXArrays.ByName, Any}'><span class="jlbinding">YAXArrays.match_axis</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
match_axis
```


Internal function

**Extended Help**

```
Match the Axis based on the AxisDescriptor.
This is used to find different axes and to make certain axis description the same.
For example to disregard differences of captialisation.
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/helpers.jl#L53-L60" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.CleanMe' href='#YAXArrays.Cubes.CleanMe'><span class="jlbinding">YAXArrays.Cubes.CleanMe</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
mutable struct CleanMe
```


Struct which describes data paths and their persistency. Non-persistend paths/files are removed at finalize step


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L55-L59" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.clean-Tuple{YAXArrays.Cubes.CleanMe}' href='#YAXArrays.Cubes.clean-Tuple{YAXArrays.Cubes.CleanMe}'><span class="jlbinding">YAXArrays.Cubes.clean</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
clean(c::CleanMe)
```


finalizer function for CleanMe struct. The main process removes all directories/files which are not persistent.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Cubes.jl#L69-L73" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.copydata-Tuple{Any, Any, Any}' href='#YAXArrays.Cubes.copydata-Tuple{Any, Any, Any}'><span class="jlbinding">YAXArrays.Cubes.copydata</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
copydata(outar, inar, copybuf)
```


Internal function which copies the data from the input `inar` into the output `outar` at the `copybuf` positions.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Rechunker.jl#L95-L98" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.optifunc-NTuple{7, Any}' href='#YAXArrays.Cubes.optifunc-NTuple{7, Any}'><span class="jlbinding">YAXArrays.Cubes.optifunc</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
optifunc(s, maxbuf, incs, outcs, insize, outsize, writefac)
```


**Internal**

This function is going to be minimized to detect the best possible chunk setting for the rechunking of the data.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/Cubes/Rechunker.jl#L19-L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.DATConfig' href='#YAXArrays.DAT.DATConfig'><span class="jlbinding">YAXArrays.DAT.DATConfig</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Configuration object of a DAT process. This holds all necessary information to perform the calculations. It contains the following fields:
- `incubes::NTuple{NIN, YAXArrays.DAT.InputCube} where NIN`: The input data cubes
  
- `outcubes::NTuple{NOUT, YAXArrays.DAT.OutputCube} where NOUT`: The output data cubes
  
- `allInAxes::Vector`: List of all axes of the input cubes
  
- `LoopAxes::Vector`: List of axes that are looped through
  
- `ispar::Bool`: Flag whether the computation is parallelized
  
- `loopcachesize::Vector{Int64}`: 
  
- `allow_irregular_chunks::Bool`: 
  
- `max_cache::Any`: Maximal size of the in memory cache
  
- `fu::Any`: Inner function which is computed
  
- `inplace::Bool`: Flag whether the computation happens in place
  
- `include_loopvars::Bool`: 
  
- `ntr::Any`: 
  
- `do_gc::Bool`: Flag if GC should be called explicitly. Probably necessary for many runs in Julia 1.9
  
- `addargs::Any`: Additional arguments for the inner function
  
- `kwargs::Any`: Additional keyword arguments for the inner function
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L216-L220" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.InputCube' href='#YAXArrays.DAT.InputCube'><span class="jlbinding">YAXArrays.DAT.InputCube</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Internal representation of an input cube for DAT operations
- `cube`: The input data
  
- `desc`: The input description given by the user/registration
  
- `axesSmall`: List of axes that were actually selected through the description
  
- `icolon`
  
- `colonperm`
  
- `loopinds`: Indices of loop axes that this cube does not contain, i.e. broadcasts
  
- `cachesize`: Number of elements to keep in cache along each axis
  
- `window`
  
- `iwindow`
  
- `windowloopinds`
  
- `iall`
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L57-L60" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.OutputCube' href='#YAXArrays.DAT.OutputCube'><span class="jlbinding">YAXArrays.DAT.OutputCube</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



Internal representation of an output cube for DAT operations

**Fields**
- `cube`: The actual outcube cube, once it is generated
  
- `cube_unpermuted`: The unpermuted output cube
  
- `desc`: The description of the output axes as given by users or registration
  
- `axesSmall`: The list of output axes determined through the description
  
- `allAxes`: List of all the axes of the cube
  
- `loopinds`: Index of the loop axes that are broadcasted for this output cube
  
- `innerchunks`
  
- `outtype`: Elementtype of the outputcube
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L126-L130" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.YAXColumn' href='#YAXArrays.DAT.YAXColumn'><span class="jlbinding">YAXArrays.DAT.YAXColumn</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
YAXColumn
```


A struct representing a single column of a YAXArray partitioned Table     # Fields 
- `inarBC`
  
- `inds`
  




<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/dciterators.jl#L40-L46" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.cmpcachmisses-Tuple{Any, Any}' href='#YAXArrays.DAT.cmpcachmisses-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.DAT.cmpcachmisses</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Function that compares two cache miss specifiers by their importance


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L921-L923" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.getFrontPerm-Tuple{Any, Any}' href='#YAXArrays.DAT.getFrontPerm-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.DAT.getFrontPerm</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Calculate an axis permutation that brings the wanted dimensions to the front


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L1166" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.getLoopCacheSize-NTuple{5, Any}' href='#YAXArrays.DAT.getLoopCacheSize-NTuple{5, Any}'><span class="jlbinding">YAXArrays.DAT.getLoopCacheSize</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Calculate optimal Cache size to DAT operation


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L1020" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.getOuttype-Tuple{Int64, Any}' href='#YAXArrays.DAT.getOuttype-Tuple{Int64, Any}'><span class="jlbinding">YAXArrays.DAT.getOuttype</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
getOuttype(outtype, cdata)
```


**Internal function**

Get the element type for the output cube


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L301-L305" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.getloopchunks-Tuple{YAXArrays.DAT.DATConfig}' href='#YAXArrays.DAT.getloopchunks-Tuple{YAXArrays.DAT.DATConfig}'><span class="jlbinding">YAXArrays.DAT.getloopchunks</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
getloopchunks(dc::DATConfig)
```


**Internal function**

```
Returns the chunks that can be looped over toghether for all dimensions.
This computation of the size of the chunks is handled by [`DiskArrays.approx_chunksize`](@ref)
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L505-L510" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.DAT.permuteloopaxes-Tuple{Any}' href='#YAXArrays.DAT.permuteloopaxes-Tuple{Any}'><span class="jlbinding">YAXArrays.DAT.permuteloopaxes</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
permuteloopaxes(dc)
```


**Internal function**

Permute the dimensions of the cube, so that the axes that are looped through are in the first positions. This is necessary for a faster looping through the data.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DAT/DAT.jl#L544-L549" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Cubes.setchunks-Tuple{Dataset, Any}' href='#YAXArrays.Cubes.setchunks-Tuple{Dataset, Any}'><span class="jlbinding">YAXArrays.Cubes.setchunks</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
setchunks(c::Dataset,chunks)
```


Resets the chunks of all or a subset YAXArrays in the dataset and returns a new Dataset. Note that this will not change the chunking of the underlying data itself, it will just make the data &quot;look&quot; like it had a different chunking. If you need a persistent on-disk representation of this chunking, use `savedataset` on the resulting array. The `chunks` argument can take one of the following forms:
- a NamedTuple or AbstractDict mapping from variable name to a description of the desired variable chunks
  
- a NamedTuple or AbstractDict mapping from dimension name to a description of the desired variable chunks
  
- a description of the desired variable chunks applied to all members of the Dataset
  

where a description of the desired variable chunks can take one of the following forms:
- a `DiskArrays.GridChunks` object
  
- a tuple specifying the chunk size along each dimension
  
- an AbstractDict or NamedTuple mapping one or more axis names to chunk sizes
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L634-L650" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.collectfromhandle-Tuple{Any, Any, Any}' href='#YAXArrays.Datasets.collectfromhandle-Tuple{Any, Any, Any}'><span class="jlbinding">YAXArrays.Datasets.collectfromhandle</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Extracts a YAXArray from a dataset handle that was just created from a arrayinfo


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L568-L570" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.createdataset-Tuple{Any, Any}' href='#YAXArrays.Datasets.createdataset-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.Datasets.createdataset</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
function createdataset(DS::Type,axlist; kwargs...)
```


Creates a new dataset with axes specified in `axlist`. Each axis must be a subtype of `CubeAxis`. A new empty Zarr array will be created and can serve as a sink for `mapCube` operations.

**Keyword arguments**
- `path=""` location where the new cube is stored
  
- `T=Union{Float32,Missing}` data type of the target cube
  
- `chunksize = ntuple(i->length(axlist[i]),length(axlist))` chunk sizes of the array
  
- `chunkoffset = ntuple(i->0,length(axlist))` offsets of the chunks
  
- `persist::Bool=true` shall the disk data be garbage-collected when the cube goes out of scope?
  
- `overwrite::Bool=false` overwrite cube if it already exists
  
- `properties=Dict{String,Any}()` additional cube properties
  
- `globalproperties=Dict{String,Any}` global attributes to be added to the dataset
  
- `fillvalue= T>:Missing ? defaultfillval(Base.nonmissingtype(T)) : nothing` fill value
  
- `datasetaxis="Variables"` special treatment of a categorical axis that gets written into separate zarr arrays
  
- `layername="layer"` Fallback name of the variable stored in the dataset if no `datasetaxis` is found
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L793-L813" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.getarrayinfo-Tuple{Any, Any}' href='#YAXArrays.Datasets.getarrayinfo-Tuple{Any, Any}'><span class="jlbinding">YAXArrays.Datasets.getarrayinfo</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Extract necessary information to create a YAXArrayBase dataset from a name and YAXArray pair


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L537-L539" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.testrange-Tuple{Any}' href='#YAXArrays.Datasets.testrange-Tuple{Any}'><span class="jlbinding">YAXArrays.Datasets.testrange</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



Test if data in x can be approximated by a step range


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L313" target="_blank" rel="noreferrer">source</a></Badge>

</details>

