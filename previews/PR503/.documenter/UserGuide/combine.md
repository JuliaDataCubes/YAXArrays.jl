
# Combine YAXArrays {#Combine-YAXArrays}

Data is often scattered across multiple files and corresponding arrays, e.g. one file per time step. This section describes methods on how to combine them into a single YAXArray.

## `cat` along an existing dimension {#cat-along-an-existing-dimension}

Here we use `cat` to combine two arrays consisting of data from the first and the second half of a year into one single array containing the whole year. We glue the arrays along the first dimension using `dims = 1`: The resulting array `whole_year` still has one dimension, i.e. time, but with 12 instead of 6 elements.

```julia
using YAXArrays
using YAXArrays: YAXArrays as YAX

first_half = YAXArray((YAX.time(1:6),), rand(6))
second_half = YAXArray((YAX.time(7:12),), rand(6))
whole_year = cat(first_half, second_half, dims = 1)
```


```
┌ 12-element YAXArray{Float64, 1} ┐
├─────────────────────────────────┴─────────────────────────────── dims ┐
  ↓ time Sampled{Int64} [1, 2, …, 11, 12] ForwardOrdered Regular Points
├───────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├───────────────────────────────────────────────────── loaded in memory ┤
  data size: 96.0 bytes
└───────────────────────────────────────────────────────────────────────┘
```


## `concatenatecubes` to a new dimension {#concatenatecubes-to-a-new-dimension}

Here we use `concatenatecubes` to combine two arrays of different variables that have the same dimensions. The resulting array `combined` has an additional dimension `variable` indicating from which array the element values originates. Note that using a `Dataset` instead is a more flexible approach in handling different variables.

```julia
using YAXArrays
using YAXArrays: YAXArrays as YAX

temperature = YAXArray((YAX.time(1:6),), rand(6))
precipitation = YAXArray((YAX.time(1:6),), rand(6))
cubes = [temperature,precipitation]
var_axis = Variables(["temp", "prep"])
combined = concatenatecubes(cubes, var_axis)
```


```
┌ 6×2 YAXArray{Float64, 2} ┐
├──────────────────────────┴──────────────────────────────── dims ┐
  ↓ time      Sampled{Int64} 1:6 ForwardOrdered Regular Points,
  → Variables Categorical{String} ["temp", "prep"] ReverseOrdered
├─────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├────────────────────────────────────────────────── loaded lazily ┤
  data size: 96.0 bytes
└─────────────────────────────────────────────────────────────────┘
```

