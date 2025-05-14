
# Compute YAXArrays {#Compute-YAXArrays}

This section describes how to create new YAXArrays by performing operations on them.
- Use [arithmetics](/UserGuide/compute#Arithmetics) to add or multiply numbers to each element of an array
  
- Use [map](/UserGuide/compute#map) to apply a more complex functions to every element of an array
  
- Use [mapslices](/UserGuide/compute#mapslices) to reduce a dimension, e.g. to get the mean over all time steps
  
- Use [mapCube](/UserGuide/compute#mapCube) to apply complex functions on an array that may change any dimensions
  

Let&#39;s start by creating an example dataset:

```julia
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
```


```
┌ 30×10×15 YAXArray{Float64, 3} ┐
├───────────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Symbol, String} with 1 entry:
  :origin => "user guide"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 35.16 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


## Modify elements of a YAXArray {#Modify-elements-of-a-YAXArray}

```julia
a[1,2,3]
```


```
0.5281581194951631
```


```julia
a[1,2,3] = 42
```


```
42
```


```julia
a[1,2,3]
```


```
42.0
```


::: warning

Some arrays, e.g. those saved in a cloud object storage are immutable making any modification of the data impossible.

:::

## Arithmetics {#Arithmetics}

Add a value to all elements of an array and save it as a new array:

```julia
a2 = a .+ 5
```


```
┌ 30×10×15 YAXArray{Float64, 3} ┐
├───────────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Any, Any}()
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 35.16 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


```julia
a2[1,2,3] == a[1,2,3] + 5
```


```
true
```


## `map` {#map}

Apply a function on every element of an array individually:

```julia
offset = 5
map(a) do x
    (x + offset) / 2 * 3
end
```


```
┌ 30×10×15 YAXArray{Float64, 3} ┐
├───────────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Symbol, String} with 1 entry:
  :origin => "user guide"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 35.16 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


This keeps all dimensions unchanged. Note, that here we can not access neighboring elements. In this case, we can use `mapslices` or `mapCube` instead. Each element of the array is processed individually.

The code runs very fast, because `map` applies the function lazily. Actual computation will be performed only on demand, e.g. when elements were explicitly requested or further computations were performed.

## `mapslices` {#mapslices}

Reduce the time dimension by calculating the average value of all points in time:

```julia
import Statistics: mean
mapslices(mean, a, dims="time")
```


```
┌ 1×10×15 YAXArray{Float64, 3} ┐
├──────────────────────────────┴───────────────────────────────────────── dims ┐
  ↓ time Sampled{IntervalSets.ClosedInterval{Date}} [2022-01-01 .. 2022-01-30] ForwardOrdered Irregular Intervals{Start},
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Any, Any}()
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 1.17 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


There is no time dimension left, because there is only one value left after averaging all time steps. We can also calculate spatial means resulting in one value per time step:

```julia
mapslices(mean, a, dims=("lat", "lon"))
```


```
┌ 30×1×1 YAXArray{Float64, 3} ┐
├─────────────────────────────┴────────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{IntervalSets.ClosedInterval{Float64}} [1.0 .. 10.0] ForwardOrdered Irregular Intervals{Start},
  ↗ lat  Sampled{IntervalSets.ClosedInterval{Float64}} [1.0 .. 5.0] ForwardOrdered Irregular Intervals{Start}
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Any, Any}()
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 240.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


## `mapCube` {#mapCube}

`mapCube` is the most flexible way to apply a function over subsets of an array. Dimensions may be added or removed.

### Operations over several YAXArrays {#Operations-over-several-YAXArrays}

Here, we will define a simple function, that will take as input several `YAXArrays`. But first, let&#39;s load the necessary packages.

```julia
using YAXArrays, Zarr
using YAXArrays: YAXArrays as YAX
using Dates
```


Define function in space and time

```julia
f(lo, la, t) = (lo + la + Dates.dayofyear(t))
```


```
f (generic function with 1 method)
```


now, `mapCube` requires this function to be wrapped as follows

```julia
function g(xout, lo, la, t)
    xout .= f.(lo, la, t)
end
```


```
g (generic function with 1 method)
```


::: info

Note the `.` after `f`, this is because we will slice across time, namely, the function is broadcasted along this dimension.

:::

Here, we do create `YAXArrays` only with the desired dimensions as

```julia
julia> lon_yax = YAXArray(lon(range(1, 15)))
```

```ansi
[90m┌ [39m[38;5;209m15-element [39mYAXArray{Int64, 1}[90m ┐[39m
[90m├───────────────────────────────┴──────────────────────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon[39m Sampled{Int64} [38;5;209m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any}()
[90m├──────────────────────────────────────────────────────────── loaded in memory ┤[39m
  data size: 120.0 bytes
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```

```julia
julia> lat_yax = YAXArray(lat(range(1, 10)))
```

```ansi
[90m┌ [39m[38;5;209m10-element [39mYAXArray{Int64, 1}[90m ┐[39m
[90m├───────────────────────────────┴──────────────────────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlat[39m Sampled{Int64} [38;5;209m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any}()
[90m├──────────────────────────────────────────────────────────── loaded in memory ┤[39m
  data size: 80.0 bytes
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


And a time Cube&#39;s Axis

```julia
tspan = Date("2022-01-01"):Day(1):Date("2022-01-30")
time_yax = YAXArray(YAX.time(tspan))
```


```
┌ 30-element YAXArray{Date, 1} ┐
├──────────────────────────────┴───────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 240.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


note that the following can be extended to arbitrary `YAXArrays` with additional data and dimensions.

Let&#39;s generate a new `cube` using `mapCube` and saving the output directly into disk.

:::tabs

== xmap (DAE)

```julia
julia> r = f.(lon_yax, lat_yax, time_yax)
```

```ansi
[90m┌ [39m[38;5;209m15[39m×[38;5;32m10[39m×[38;5;81m30[39m YAXArray{Int64, 3}[90m ┐[39m
[90m├─────────────────────────────┴────────────────────────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Int64} [38;5;209m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Int64} [38;5;32m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{Date} [38;5;81mDate("2022-01-01"):Dates.Day(1):Date("2022-01-30")[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Any, Any}()
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 35.16 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


or as 

```julia
julia> r = xmap(f, lon_yax, lat_yax, time_yax, output=XOutput(outtype=Float32), inplace=false)
```

```ansi
[90m┌ [39m[38;5;209m15[39m×[38;5;32m10[39m×[38;5;81m30[39m YAXArray{Float32, 3}[90m ┐[39m
[90m├───────────────────────────────┴──────────────────────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Int64} [38;5;209m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Int64} [38;5;32m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{Date} [38;5;81mDate("2022-01-01"):Dates.Day(1):Date("2022-01-30")[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Any, Any}()
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 17.58 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


and triggering the computation and saving to `zarr` is done with `compute_to_zarr`:

```julia
julia> gen_cube = compute_to_zarr(Dataset(layer=r), "my_gen_cube.zarr", overwrite=true, max_cache=1e9)
```

```ansi
[33m[1m┌ [22m[39m[33m[1mWarning: [22m[39mThe selected optimization algorithm requires second order derivatives, but `SecondOrder` ADtype was not provided. 
[33m[1m│ [22m[39m        So a `SecondOrder` with ADTypes.AutoForwardDiff() for both inner and outer will be created, this can be suboptimal and not work in some cases so 
[33m[1m│ [22m[39m        an explicit `SecondOrder` ADtype is recommended.
[33m[1m└ [22m[39m[90m@ OptimizationBase ~/.julia/packages/OptimizationBase/UXLhR/src/cache.jl:49[39m
YAXArray Dataset
Shared Axes:
  ([38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Int64} [38;5;209m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Int64} [38;5;32m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{Date} [38;5;81mDate("2022-01-01"):Dates.Day(1):Date("2022-01-30")[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m)

[94mVariables: [39m
layer
```


note that it takes as input a `Dataset`.

== mapCube

```julia
julia> gen_cube = mapCube(g, (lon_yax, lat_yax, time_yax);
           indims = (InDims(), InDims(), InDims("time")),
           outdims = OutDims("time", overwrite=true, path="my_gen_cube.zarr", backend=:zarr,
           outtype = Float32)
           # max_cache=1e9
       )
```

```ansi
[90m┌ [39m[38;5;209m30[39m×[38;5;32m15[39m×[38;5;81m10[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├───────────────────────────────────────────────┴──────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Sampled{Date} [38;5;209mDate("2022-01-01"):Dates.Day(1):Date("2022-01-30")[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlon [39m Sampled{Int64} [38;5;32m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mlat [39m Sampled{Int64} [38;5;81m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 1 entry:
  "missing_value" => 1.0f32
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 17.58 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


::: info &quot;time axis goes first&quot;

Note that currently the `time` axis in the output cube goes first.

:::

Check that it is working

```julia
julia> gen_cube.data[1, :, :]
```

```ansi
15×10 Matrix{Union{Missing, Float32}}:
  3.0   4.0   5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0
  4.0   5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0
  5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0
  6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0
  7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0
  8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0
  9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0
 10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0
 11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0
 12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0
 13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0
 14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0
 15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0
 16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0  25.0
 17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0  25.0  26.0
```


but, we can generate a another cube with a different `output order` as follows

```julia
julia> gen_cube = mapCube(g, (lon_yax, lat_yax, time_yax);
           indims = (InDims("lon"), InDims(), InDims()),
           outdims = OutDims("lon", overwrite=true, path="my_gen_cube.zarr", backend=:zarr,
           outtype = Float32)
           # max_cache=1e9
       )
```

```ansi
[90m┌ [39m[38;5;209m15[39m×[38;5;32m10[39m×[38;5;81m30[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├───────────────────────────────────────────────┴──────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Int64} [38;5;209m1:15[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Int64} [38;5;32m1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{Date} [38;5;81mDate("2022-01-01"):Dates.Day(1):Date("2022-01-30")[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 1 entry:
  "missing_value" => 1.0f32
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 17.58 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


::: info

Note that now the broadcasted dimension is `lon`.

:::

we can see this by slicing on the last dimension now

```julia
gen_cube.data[:, :, 1]
```


```
15×10 Matrix{Union{Missing, Float32}}:
  3.0   4.0   5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0
  4.0   5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0
  5.0   6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0
  6.0   7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0
  7.0   8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0
  8.0   9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0
  9.0  10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0
 10.0  11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0
 11.0  12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0
 12.0  13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0
 13.0  14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0
 14.0  15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0
 15.0  16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0
 16.0  17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0  25.0
 17.0  18.0  19.0  20.0  21.0  22.0  23.0  24.0  25.0  26.0
```


which outputs the same as the `gen_cube.data[1, :, :]` called above.

### OutDims and YAXArray Properties {#OutDims-and-YAXArray-Properties}

Here, we will consider different scenarios, namely how we deal with different input cubes and how to specify the output ones. We will illustrate this with the following test example and the subsequent function definitions. 

```julia
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
```


```
┌ 5×4×3×2 YAXArray{Int64, 4} ┐
├────────────────────────────┴─────────────────────────────────────────── dims ┐
  ↓ time      Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon       Sampled{Float64} 1.0:1.0:4.0 ForwardOrdered Regular Points,
  ↗ lat       Sampled{Float64} 1.0:1.0:3.0 ForwardOrdered Regular Points,
  ⬔ Variables Categorical{String} ["a", "b"] ForwardOrdered
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, String} with 1 entry:
  "description" => "multi dimensional test cube"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 960.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


#### One InDims to many OutDims {#One-InDims-to-many-OutDims}

In the following function, note how the outputs are defined first and the inputs later.

```julia
function one_to_many(xout_one, xout_two, xout_flat, xin_one)
    xout_one .= f1.(xin_one)
    xout_two .= f2.(xin_one)
    xout_flat .= sum(xin_one)
    return nothing
end

f1(xin) = xin + 1
f2(xin) = xin + 2
```


```
f2 (generic function with 1 method)
```


```julia
properties_one = Dict{String, Any}("name" => "plus_one")
properties_two = Dict{String, Any}("name" => "plus_two");
```


:::tabs

== xmap (DAE)

```julia
output_one = XOutput(yax_test.time; properties=properties_one)
output_two = XOutput(yax_test.time; properties=properties_two)
output_flat = XOutput(;)

ds = xmap(one_to_many, yax_test⊘:time,
    output=(output_one, output_two, output_flat)
    );
```


== mapCube

now, we define `InDims` and `OutDims`:

```julia
indims_one   = InDims("Time")
# outputs dimension
outdims_one = OutDims("Time"; properties=properties_one)
outdims_two = OutDims("Time"; properties=properties_two)
outdims_flat = OutDims(;) # it will get the default `layer` name if open as dataset
```


```julia
ds = mapCube(one_to_many, yax_test,
    indims = indims_one,
    outdims = (outdims_one, outdims_two, outdims_flat));
```


:::

let&#39;s see the second output

```julia
ds[2]
```


```
┌ 5×4×3×2 YAXArray{Union{Missing, Int64}, 4} ┐
├────────────────────────────────────────────┴─────────────────────────── dims ┐
  ↓ time      Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon       Sampled{Float64} 1.0:1.0:4.0 ForwardOrdered Regular Points,
  ↗ lat       Sampled{Float64} 1.0:1.0:3.0 ForwardOrdered Regular Points,
  ⬔ Variables Categorical{String} ["a", "b"] ForwardOrdered
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 1 entry:
  "name" => "plus_two"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 960.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


#### Many InDims to many OutDims {#Many-InDims-to-many-OutDims}

Let&#39;s consider a second test set

```julia
properties_2d = Dict("description" => "2d dimensional test cube")
yax_2d = YAXArray(axlist[2:end], rand(-1:1, 4, 3, 2), properties_2d)
```


```
┌ 4×3×2 YAXArray{Int64, 3} ┐
├──────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ lon       Sampled{Float64} 1.0:1.0:4.0 ForwardOrdered Regular Points,
  → lat       Sampled{Float64} 1.0:1.0:3.0 ForwardOrdered Regular Points,
  ↗ Variables Categorical{String} ["a", "b"] ForwardOrdered
├─────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, String} with 1 entry:
  "description" => "2d dimensional test cube"
├─────────────────────────────────────────────────────── loaded in memory ┤
  data size: 192.0 bytes
└─────────────────────────────────────────────────────────────────────────┘
```


The function definitions operating in this case are as follows

```julia
function many_to_many(xout_one, xout_two, xout_flat, xin_one, xin_two, xin_drei)
    xout_one .= f1.(xin_one)
    xout_two .= f2mix.(xin_one, xin_two)
    xout_flat .= sum(xin_drei) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end
f2mix(xin_xyt, xin_xy) = xin_xyt - xin_xy
```


:::tabs

== xmap (DAE)

```julia
output_time = XOutput(yax_test.time)
output_flat = XOutput()

r1, r2, r3 = xmap(many_to_many, yax_test⊘:time, yax_2d, yax_test⊘"time",
    output =(output_time, output_time, output_flat), inplace=true);
dsout = Dataset(many_to_many_two=r2)

compute_to_zarr(dsout, "test_mm.zarr", overwrite=true)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ time      Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon       Sampled{Float64} 1.0:1.0:4.0 ForwardOrdered Regular Points,
  ↗ lat       Sampled{Float64} 1.0:1.0:3.0 ForwardOrdered Regular Points,
  ⬔ Variables Categorical{String} ["a", "b"] ForwardOrdered)

Variables: 
many_to_many_two


```


== mapCube

#### Specify path in OutDims {#Specify-path-in-OutDims}

```julia
indims_one   = InDims("Time")
indims_2d   = InDims() # ? it matches only to the other 2 dimensions and uses the same values for each time step
properties = Dict{String, Any}("name"=> "many_to_many_two")
outdims_one = OutDims("Time")
outdims_two = OutDims("Time"; path = "test_mm.zarr", properties, overwrite=true)
outdims_flat = OutDims();
```


```julia
ds = mapCube(many_to_many, (yax_test, yax_2d, yax_test),
    indims = (indims_one, indims_2d, indims_one),
    outdims = (outdims_one, outdims_two, outdims_flat));
```


And we can open the one that was saved directly to disk.

```julia
ds_mm = open_dataset("test_mm.zarr")
```


```
YAXArray Dataset
Shared Axes: 
  (↓ time Sampled{DateTime} [2022-01-01T00:00:00, …, 2022-01-05T00:00:00] ForwardOrdered Irregular Points,
  → lon  Sampled{Float64} 1.0:1.0:4.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:1.0:3.0 ForwardOrdered Regular Points)

Variables: 
a, b


```


:::

### Different InDims names {#Different-InDims-names}

Here, the goal is to operate at the pixel level (longitude, latitude), and then apply the corresponding function to the extracted values. Consider the following toy cubes:

```julia
Random.seed!(123)
data = rand(3.0:5.0, 5, 4, 3)

axlist = (lon(1:4), lat(1:3), Dim{:depth}(1:7),)
yax_2d = YAXArray(axlist, rand(-3.0:0.0, 4, 3, 7))
```


```
┌ 4×3×7 YAXArray{Float64, 3} ┐
├────────────────────────────┴──────────────────────── dims ┐
  ↓ lon   Sampled{Int64} 1:4 ForwardOrdered Regular Points,
  → lat   Sampled{Int64} 1:3 ForwardOrdered Regular Points,
  ↗ depth Sampled{Int64} 1:7 ForwardOrdered Regular Points
├───────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├───────────────────────────────────────── loaded in memory ┤
  data size: 672.0 bytes
└───────────────────────────────────────────────────────────┘
```


and 

```julia
Random.seed!(123)
data = rand(3.0:5.0, 5, 4, 3)

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-05")),
    lon(1:4),
    lat(1:3),
    )

properties = Dict("description" => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)
```


```
┌ 5×4×3 YAXArray{Float64, 3} ┐
├────────────────────────────┴─────────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon  Sampled{Int64} 1:4 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Int64} 1:3 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, String} with 1 entry:
  "description" => "multi dimensional test cube"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 480.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


and the corresponding functions 

```julia
function mix_time_depth(xin_xyt, xin_xyz)
    s = sum(abs.(xin_xyz))
    return xin_xyt.^2 .+ s
end

function time_depth(xout, xin_one, xin_two)
    xout .= mix_time_depth(xin_one, xin_two)
    # Note also that there is no dot anymore in the function application!
    return nothing
end
```


```
time_depth (generic function with 1 method)
```


with the final mapCube operation as follows

:::tabs

== xmap (DAE)

```julia
ds = xmap(mix_time_depth, yax_test ⊘ :time, yax_2d ⊘ :depth,
    output = XOutput(yax_test.time), inplace=false)
```


```
┌ 5×4×3×1 YAXArray{Float64, 4} ┐
├──────────────────────────────┴───────────────────────────────────────── dims ┐
  ↓ time  Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon   Sampled{Int64} 1:4 ForwardOrdered Regular Points,
  ↗ lat   Sampled{Int64} 1:3 ForwardOrdered Regular Points,
  ⬔ depth Sampled{IntervalSets.ClosedInterval{Int64}} [1 .. 7] ForwardOrdered Irregular Intervals{Start}
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{Any, Any}()
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 480.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


== mapCube

```julia
ds = mapCube(time_depth, (yax_test, yax_2d),
    indims = (InDims("Time"), InDims("depth")), # ? anchor dimensions and then map over the others.
    outdims = OutDims("Time"))
```


```
┌ 5×4×3 YAXArray{Union{Missing, Float64}, 3} ┐
├────────────────────────────────────────────┴─────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-05") ForwardOrdered Regular Points,
  → lon  Sampled{Int64} 1:4 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Int64} 1:3 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 480.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


:::
- TODO:
  - Example passing additional arguments to function. 
    
  - MovingWindow
    
  - Multiple variables outputs, OutDims, in the same YAXArray
    
  

### Creating a vector array {#Creating-a-vector-array}

Here we transform a raster array with spatial dimension lat and lon into a vector array having just one spatial dimension i.e. region. First, create the raster array:

```julia
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
```


```
┌ 30×10×15 YAXArray{Float64, 3} ┐
├───────────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 35.16 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


Then, create a Matrix with the same spatial dimensions indicating to which region each point belongs to:

```julia
regions_mat = map(Iterators.product(raster_arr.lon, raster_arr.lat)) do (lon, lat)
    1 <= lon < 10 && 1 <= lat < 5 && return "A"
    1 <= lon < 10 && 5 <= lat < 10 && return "B"
    10 <= lon < 15 && 1 <= lat < 5 && return "C"
    return "D"
end
regions_mat = DimArray(regions_mat, (raster_arr.lon, raster_arr.lat))
```


```
┌ 10×15 DimArray{String, 2} ┐
├───────────────────────────┴──────────────────────────────────────────── dims ┐
  ↓ lon Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  → lat Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
└──────────────────────────────────────────────────────────────────────────────┘
  ↓ →  1.0   1.28571  1.57143  1.85714  …  4.14286  4.42857  4.71429  5.0
  1.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  2.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  3.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  4.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  5.0   "A"   "A"      "A"      "A"     …   "A"      "A"      "A"      "B"
  6.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  7.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  8.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
  9.0   "A"   "A"      "A"      "A"         "A"      "A"      "A"      "B"
 10.0   "C"   "C"      "C"      "C"     …   "C"      "C"      "C"      "D"
```


which has the same spatial dimensions as the raster array at any given point in time:

```julia
DimArray(raster_arr[time = 1])
```


```
┌ 10×15 DimArray{Float64, 2} ┐
├────────────────────────────┴─────────────────────────────────────────── dims ┐
  ↓ lon Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  → lat Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
└──────────────────────────────────────────────────────────────────────────────┘
  ↓ →  1.0       1.28571   1.57143    …  4.42857   4.71429   5.0
  1.0  0.17593   0.417937  0.0723492     0.178603  0.781773  0.875658
  2.0  0.701332  0.15394   0.685454      0.372761  0.984803  0.472308
  3.0  0.120997  0.829062  0.684389      0.463503  0.840389  0.536399
  ⋮                                   ⋱                      ⋮
  8.0  0.145747  0.432286  0.465103      0.889583  0.514979  0.671662
  9.0  0.538981  0.497189  0.167676      0.595405  0.752417  0.93986
 10.0  0.824354  0.376135  0.551732   …  0.101524  0.121947  0.508557
```


Now we calculate the list of corresponding points for each region. This will be re-used for each point in time during the final `mapCube`. In addition, this avoids the allocation of unnecessary memory.

```julia
regions = ["A", "B", "C", "D"]
points_of_regions = map(enumerate(regions)) do (i,region)
    region => findall(isequal(region), regions_mat)
end |> Dict |> sort
```


```
OrderedCollections.OrderedDict{String, Vector{CartesianIndex{2}}} with 4 entries:
  "A" => [CartesianIndex(1, 1), CartesianIndex(2, 1), CartesianIndex(3, 1), Car…
  "B" => [CartesianIndex(1, 15), CartesianIndex(2, 15), CartesianIndex(3, 15), …
  "C" => [CartesianIndex(10, 1), CartesianIndex(10, 2), CartesianIndex(10, 3), …
  "D" => [CartesianIndex(10, 15)]
```


Finally, we can transform the entire raster array:

```julia
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
```


```
┌ 4×30 YAXArray{Union{Missing, Float64}, 2} ┐
├───────────────────────────────────────────┴──────────────────────────── dims ┐
  ↓ region Categorical{String} ["A", "B", "C", "D"] ForwardOrdered,
  → time   Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 960.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


This gives us a vector array with only one spatial dimension, i.e. the region. Note that we still have 30 points in time. The transformation was applied for each date separately.

Hereby, `xin` is a 10x15 array representing a map at a given time and `xout` is a 4 element vector of missing values initially representing the 4 regions at that date. Then, we set each output element by the sum of all corresponding points

## Distributed Computation {#Distributed-Computation}

All map methods apply a function on all elements of all non-input dimensions separately. This allows to run each map function call in parallel. For example, we can execute each date of a time series in a different CPU thread during spatial aggregation. 

The following code does a time mean over all grid points using multiple CPUs of a local machine:

```julia
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

```


:::tabs

== xmap (DAE)

```julia
meantime = xmap(mymean, a⊘:time)
# and save!
compute_to_zarr(Dataset(time_mean=meantime), tempname())
```


== mapCube

```julia
mapCube(mymean, a, indims=InDims("time"), outdims=OutDims())
```


:::

In the last example, `mapCube` was used to map the `mymean` function. `mapslices` is a convenient function that can replace `mapCube`, where you can omit defining an extra function with the output argument as an input (e.g. `mymean`). It is possible to simply use `mapslice`

```julia
mapslices(mean ∘ skipmissing, a, dims="time")
```


It is also possible to distribute easily the workload on a cluster, with little modification to the code. To do so, we use the `ClusterManagers` package.

```julia
using Distributed
using ClusterManagers
addprocs(SlurmManager(10))
```

