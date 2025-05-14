
# Create YAXArrays and Datasets {#Create-YAXArrays-and-Datasets}

This section describes how to create arrays and datasets by filling values directly.

## Create a YAXArray {#Create-a-YAXArray}

We can create a new YAXArray by filling the values directly:

```julia
using YAXArrays
using YAXArrays: YAXArrays as YAX

a1 = YAXArray(rand(10, 20, 5))
```


```
┌ 10×20×5 YAXArray{Float64, 3} ┐
├──────────────────────────────┴───────────────────────────────── dims ┐
  ↓ Dim_1 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points,
  → Dim_2 Sampled{Int64} Base.OneTo(20) ForwardOrdered Regular Points,
  ↗ Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points
├──────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────── loaded in memory ┤
  data size: 7.81 KB
└──────────────────────────────────────────────────────────────────────┘
```


The dimensions have only generic names, e.g. `Dim_1` and only integer values. We can also specify the dimensions with custom names enabling easier access:

```julia
using Dates

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
)
data2 = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a2 = YAXArray(axlist, data2, properties)
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


```julia
a2.properties
```


```
Dict{Symbol, String} with 1 entry:
  :origin => "user guide"
```


```julia
a2.axes
```


```
(↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
→ lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points)
```


## Create a Dataset {#Create-a-Dataset}

```julia
data3 = rand(30, 10, 15)
a3 = YAXArray(axlist, data3, properties)

arrays = Dict(:a2 => a2, :a3 => a3)
ds = Dataset(; properties, arrays...)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ time Sampled{Date} Date("2022-01-01"):Dates.Day(1):Date("2022-01-30") ForwardOrdered Regular Points,
  → lon  Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat  Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points)

Variables: 
a2, a3

Properties: Dict(:origin => "user guide")

```

