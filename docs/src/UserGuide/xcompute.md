# Compute YAXArrays

This section describes how to create new YAXArrays by performing operations on them.

- Use [arithmetics](#Arithmetics) to add or multiply numbers to each element of an array
- Use [map](#map) to apply a more complex functions to every element of an array
- Use [mapslices](#mapslices) to reduce a dimension, e.g. to get the mean over all time steps
- Use [mapCube](#mapCube) to apply complex functions on an array that may change any dimensions


Let's start by creating an example dataset:

````@example compute
using YAXArrays
using YAXArrays: YAXArrays as YAX
using Dates

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
)
data = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a = YAXArray(axlist, data, properties)
````

## Modify elements of a YAXArray

````@example compute
a[1,2,3]
````

````@example compute
a[1,2,3] = 42
````

````@example compute
a[1,2,3]
````

::: warning

Some arrays, e.g. those saved in a cloud object storage are immutable making any modification of the data impossible.

:::


## Arithmetics

Add a value to all elements of an array and save it as a new array:

````@example compute
a2 = a .+ 5
````

broadcast is alway a lazy operation on YAXArrays, so need to access some values to actually start the computation:

````@example compute
a2[1,2,3] == a[1,2,3] + 5
````

## `map`

Apply a function on every element of an array individually:

````@example compute
offset = 5
map(a) do x
    (x + offset) / 2 * 3
end
````

This keeps all dimensions unchanged.
Note, that here we can not access neighboring elements.
In this case, we can use `mapslices` or `mapCube` instead.
Each element of the array is processed individually.

The code runs very fast, because `map` applies the function lazily.
Actual computation will be performed only on demand, e.g. when elements were explicitly requested or further computations were performed.


## `mapslices`

Reduce the time dimension by calculating the average value of all points in time:

````@example compute
import Statistics: mean
mapslices(mean, a, dims="Time")
````
There is no time dimension left, because there is only one value left after averaging all time steps.
We can also calculate spatial means resulting in one value per time step:

````@example compute
mapslices(mean, a, dims=("lat", "lon"))
````

## `mapCube`

`mapCube` is the most flexible way to apply a function over subsets of an array.
Dimensions may be added or removed.

### Operations over several YAXArrays

Here, we will define a simple function, that will take as input several `YAXArrays`. But first, let's load the necessary packages.

````@example mapCube
using YAXArrays, Zarr
using YAXArrays: YAXArrays as YAX
using Dates
````

Define function in space and time

````@example mapCube
f(lo, la, t) = (lo + la + Dates.dayofyear(t))
````


Here, we do create `YAXArrays` only with the desired dimensions as

````@ansi mapCube
lon_yax = YAXArray(lon(range(1, 15)))
lat_yax = YAXArray(lat(range(1, 10)))
````

And a time Cube's Axis

````@example mapCube
tspan = Date("2022-01-01"):Day(1):Date("2022-01-30")
time_yax = YAXArray(YAX.time(tspan))
````

note that the following can be extended to arbitrary `YAXArrays` with additional data and dimensions.

Let's generate a new `cube` using `xmap` 

````@ansi mapCube
expanded_cube = xmap(f,lon_yax,lat_yax,time_yax, output=XOutput(outtype=Float32),inplace=false)
````

Since `xmap` is operating in a lazy fashion, it can be directly used for follow-up operations. However, if we
want to store the result to disk one can explicitly compute the result:

````@ansi mapCube
gen_cube = compute_to_zarr(expanded_cube, "my_gen_cube.zarr", overwrite=true, max_cache=1e9)
````

::: info "time axis goes first"

Note that currently the `time` axis in the output cube goes first.

:::


Check that it is working

````@ansi mapCube
gen_cube.data[1, :, :]
````


### OutDims and YAXArray Properties

Here, we will consider different scenarios, namely how we deal with different input cubes and how to specify the output ones. We will illustrate this with the following test example and the subsequent function definitions. 

````@example outdims
using YAXArrays
using YAXArrays: YAXArrays as YAX
using Dates
using Zarr
using Random

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-05")),
    lon(range(1, 4, length=4)),
    lat(range(1, 3, length=3)),
    Variables(["a", "b"])
)

Random.seed!(123)
data = rand(1:5, 5, 4, 3, 2)

properties = Dict("description" => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)
````

#### One InDims to many OutDims
In the following function, note how the outputs are defined first and the inputs later.

````@example outdims
function one_to_many(xout_one, xout_two, xout_flat, xin_one)
    xout_one .= f1.(xin_one)
    xout_two .= f2.(xin_one)
    xout_flat .= sum(xin_one)
    return nothing
end

f1(xin) = xin + 1
f2(xin) = xin + 2
````
now, we define `InDims` and `OutDims`:

````@example outdims
indims_one   = InDims("Time")
# outputs dimension
properties_one = Dict{String, Any}("name" => "plus_one")
properties_two = Dict{String, Any}("name" => "plus_two")

output_one = XOutput(yax_test.time; properties=properties_one)
output_two = XOutput(yax_test.time; properties=properties_two)
output_flat = XOutput(;) 
````

````@example outdims
ds = mapCube(one_to_many, yax_test,
    indims = indims_one,
    outdims = (outdims_one, outdims_two, outdims_flat));
nothing # hide
````

let's see the second output

````@example outdims
ds[2]
````

#### Many InDims to many OutDims

Let's consider a second test set

````@example outdims
properties_2d = Dict("description" => "2d dimensional test cube")
yax_2d = YAXArray(axlist[2:end], rand(-1:1, 4, 3, 2), properties_2d)
````

The function definitions operating in this case are as follows

````@example outdims
function many_to_many(xout_one, xout_two, xout_flat, xin_one, xin_two, xin_drei)
    xout_one .= f1.(xin_one)
    xout_two .= f2mix.(xin_one, xin_two)
    xout_flat .= sum(xin_drei) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end
f2mix(xin_xyt, xin_xy) = xin_xyt - xin_xy
````

#### Specify path in OutDims

````@example outdims
output_time = XOutput(yax_test.time)
output_flat = XOutput()
output = (output_time,output_time,output_flat)
````

````@example outdims
ds = xmap(many_to_many, yax_test⊘:time, yax_2d, yax_test⊘:time,output = output);
compute_to_zarr(Dataset(many_to_many_two=ds[2]),"test_mm.zarr",overwrite=true)
nothing # hide
````

And we can open the one that was saved directly to disk.

````@example outdims
ds_mm = open_dataset("test_mm.zarr")
````

### Different InDims names

Here, the goal is to operate at the pixel level (longitude, latitude), and then apply the corresponding function to the extracted values. Consider the following toy cubes:

````@example outdims
Random.seed!(123)
data = rand(3.0:5.0, 5, 4, 3)

axlist = (lon(1:4), lat(1:3), Dim{:depth}(1:7),)
yax_2d = YAXArray(axlist, rand(-3.0:0.0, 4, 3, 7))
````

and 

````@example outdims
Random.seed!(123)
data = rand(3.0:5.0, 5, 4, 3)

axlist = (YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-05")),
    lon(1:4), lat(1:3),)

properties = Dict("description" => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)
````
and the corresponding functions 

````@example outdims
function mix_time_depth(xin_xyt, xin_xyz)
    s = sum(abs.(xin_xyz))
    return xin_xyt.^2 .+ s
end
````

with the final mapCube operation as follows

````@example outdims
ds = xmap(mix_time_depth, yax_test⊘"time", yax_2d⊘"depth",
    output = XOutput(yax_test.time),inplace=false)

````

- TODO:
    - Example passing additional arguments to function. 
    - MovingWindow
    - Multiple variables outputs, OutDims, in the same YAXArray

### Creating a vector array

Here we transform a raster array with spatial dimension lat and lon into a vector array having just one spatial dimension i.e. region.
First, create the raster array:

````@example compute_mapcube
using YAXArrays
using YAXArrays: YAXArrays as YAX
using DimensionalData
using Dates

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
)
data = rand(30, 10, 15)
raster_arr = YAXArray(axlist, data)
````

Then, create a Matrix with the same spatial dimensions indicating to which region each point belongs to:

````@example compute_mapcube
regions_mat = map(Iterators.product(raster_arr.lon, raster_arr.lat)) do (lon, lat)
    1 <= lon < 10 && 1 <= lat < 5 && return "A"
    1 <= lon < 10 && 5 <= lat < 10 && return "B"
    10 <= lon < 15 && 1 <= lat < 5 && return "C"
    return "D"
end
regions_mat = DimArray(regions_mat, (raster_arr.lon, raster_arr.lat))
````

which has the same spatial dimensions as the raster array at any given point in time:

````@example compute_mapcube
DimArray(raster_arr[time = 1])
````

Now we calculate the list of corresponding points for each region.
This will be re-used for each point in time during the final `mapCube`.
In addition, this avoids the allocation of unnecessary memory.

````@example compute_mapcube
regions = ["A", "B", "C", "D"]
points_of_regions = map(enumerate(regions)) do (i,region)
    region => findall(isequal(region), regions_mat)
end |> Dict |> sort
````

Finally, we can transform the entire raster array:

````@example compute_mapcube
vector_array = mapCube(
    raster_arr,
    indims=InDims("lon", "lat"),
    outdims=OutDims(Dim{:region}(regions))
) do xout, xin
    for (region_pos, points) in enumerate(points_of_regions.vals)
        # aggregate values of points in the current region at the current date
        xout[region_pos] = sum(view(xin, points))
    end
end
````

This gives us a vector array with only one spatial dimension, i.e. the region.
Note that we still have 30 points in time.
The transformation was applied for each date separately.

Hereby, `xin` is a 10x15 array representing a map at a given time and `xout` is a 4 element vector of missing values initially representing the 4 regions at that date. Then, we set each output element by the sum of all corresponding points


## Distributed Computation

All map methods apply a function on all elements of all non-input dimensions separately.
This allows to run each map function call in parallel.
For example, we can execute each date of a time series in a different CPU thread during spatial aggregation. 

The following code does a time mean over all grid points using multiple CPUs of a local machine:

````julia
using YAXArrays
using YAXArrays: YAXArrays as YAX
using Dates
using Distributed

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
)
data = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a = YAXArray(axlist, data, properties)

addprocs(2)

@everywhere begin
  using YAXArrays
  using Zarr
  using Statistics
end

@everywhere function mymean(output, pixel)
  @show "doing a mean"
     output[:] .= mean(pixel)
end

mapCube(mymean, a, indims=InDims("time"), outdims=OutDims())
````

In the last example, `mapCube` was used to map the `mymean` function. `mapslices` is a convenient function that can replace `mapCube`, where you can omit defining an extra function with the output argument as an input (e.g. `mymean`). It is possible to simply use `mapslice`

````julia
mapslices(mean ∘ skipmissing, a, dims="time")
````

It is also possible to distribute easily the workload on a cluster, with little modification to the code. To do so, we use the `ClusterManagers` package.

````julia
using Distributed
using ClusterManagers
addprocs(SlurmManager(10))
````