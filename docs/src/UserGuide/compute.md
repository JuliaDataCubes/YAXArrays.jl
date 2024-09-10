# Compute YAXArrays

This section describes how to create new YAXArrays by performing operations on them.

- Use [arithmetics](#Arithmetics) to add or multiply numbers to each element of an array
- Use [map](#map) to apply a more complex functions to every element of an array
- Use [mapslices](#mapslices) to reduce a dimension, e.g. to get the mean over all time steps
- Use [mapCube](#mapCube) to apply complex functions on an array that may change any dimensions


Let's start by creating an example dataset:

````@example compute
using YAXArrays
using Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
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
using Dates
````

Define function in space and time

````@example mapCube
f(lo, la, t) = (lo + la + Dates.dayofyear(t))
````

now, `mapCube` requires this function to be wrapped as follows

````@example mapCube
function g(xout, lo, la, t)
    xout .= f.(lo, la, t)
end
````

::: tip
Note the `.` after `f`, this is because we will slice across time, namely, the function is broadcasted along this dimension.
:::

Here, we do create `YAXArrays` only with the desired dimensions as

````@ansi mapCube
lon = YAXArray(Dim{:lon}(range(1, 15)))
````

````@ansi mapCube
lat = YAXArray(Dim{:lat}(range(1, 10)))
````

And a time Cube's Axis

````@ansi mapCube
tspan = Date("2022-01-01"):Day(1):Date("2022-01-30")
time = YAXArray(Dim{:time}(tspan))
````

note that the following can be extended to arbitrary `YAXArrays` with additional data and dimensions.

Let's generate a new `cube` using `mapCube` and saving the output directly into disk.

````@ansi mapCube
gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims(), InDims(), InDims("time")),
    outdims = OutDims("time", overwrite=true, path="my_gen_cube.zarr", backend=:zarr, outtype=Float32)
    # max_cache=1e9
)
````

::: warning "time axis is first"
Note that currently the `time` axis in the output cube goes first.
:::

Check that it is working

````@ansi mapCube
gen_cube.data[1, :, :]
````

but, we can generate a another cube with a different `output order` as follows

````@ansi mapCube
gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims("lon"), InDims(), InDims()),
    outdims = OutDims("lon", overwrite=true, path="my_gen_cube.zarr", backend=:zarr, outtype=Float32)
    # max_cache=1e9
)
````

::: info
Note that now the broadcasted dimension is `lon`.
:::

we can see this by slicing on the last dimension now

````@example mapCube
gen_cube.data[:, :, 1]
````

which outputs the same as the `gen_cube.data[1, :, :]` called above.

### Creating a vector array

Here we transform a raster array with spatial dimension lat and lon into a vector array having just one spatial dimension i.e. region.
First, create the raster array:

````@example compute_mapcube
using YAXArrays
using DimensionalData
using Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
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
using Dates
using Distributed

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
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