
# Getting Started {#Getting-Started}

## Installation {#Installation}

Install [Julia v1.10 or above](https://julialang.org/downloads/). YAXArrays.jl is available through the Julia package manager. You can enter it by pressing `]` in the REPL and then typing

```julia
pkg> add YAXArrays
```


Alternatively, you can also do

```julia
import Pkg; Pkg.add("YAXArrays")
```


## Quickstart {#Quickstart}

Create a simple array from random numbers given the size of each dimension or axis:

```julia
using YAXArrays
using YAXArrays: YAXArrays as YAX

a = YAXArray(rand(2,3))
```


```
┌ 2×3 YAXArray{Float64, 2} ┐
├──────────────────────────┴──────────────────────────────────── dims ┐
  ↓ Dim_1 Sampled{Int64} Base.OneTo(2) ForwardOrdered Regular Points,
  → Dim_2 Sampled{Int64} Base.OneTo(3) ForwardOrdered Regular Points
├─────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├─────────────────────────────────────────────────── loaded in memory ┤
  data size: 48.0 bytes
└─────────────────────────────────────────────────────────────────────┘
```


Assemble a more complex `YAXArray` with 4 dimensions, i.e. time, x, y and a variable type:

```julia
# axes or dimensions with name and tick values
axlist = (
    YAX.time(range(1, 20, length=20)),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
    Variables(["temperature", "precipitation"])
)

# the actual data matching the dimensions defined in axlist
data = rand(20, 10, 15, 2)

# metadata about the array
props = Dict(
    "origin" => "YAXArrays.jl example",
    "x" => "longitude",
    "y" => "latitude",
);

a2 = YAXArray(axlist, data, props)
```


```
┌ 20×10×15×2 YAXArray{Float64, 4} ┐
├─────────────────────────────────┴────────────────────────────────────── dims ┐
  ↓ time      Sampled{Float64} 1.0:1.0:20.0 ForwardOrdered Regular Points,
  → lon       Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  ↗ lat       Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points,
  ⬔ Variables Categorical{String} ["temperature", "precipitation"] ReverseOrdered
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, String} with 3 entries:
  "y"      => "latitude"
  "x"      => "longitude"
  "origin" => "YAXArrays.jl example"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 46.88 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


Get the temperature map at the first point in time:

```julia
a2[Variables=At("temperature"), time=1].data
```


```
10×15 view(::Array{Float64, 4}, 1, :, :, 1) with eltype Float64:
 0.259455  0.565546  0.431802   0.644072   …  0.321157  0.203353   0.716461
 0.289588  0.586024  0.790949   0.724898      0.792641  0.592895   0.538893
 0.86017   0.308259  0.666173   0.720056      0.392909  0.448963   0.597863
 0.640515  0.944409  0.359252   0.378128      0.621308  0.544106   0.162823
 0.167987  0.794531  0.0376155  0.0473649     0.920234  0.308741   0.966306
 0.337646  0.722448  0.626195   0.387071   …  0.181039  0.0747867  0.461716
 0.109472  0.250091  0.39347    0.534387      0.892546  0.981061   0.587513
 0.780845  0.267237  0.553509   0.359267      0.16458   0.393909   0.609577
 0.571845  0.634497  0.358193   0.488578      0.956751  0.19141    0.843401
 0.214923  0.375177  0.430336   0.0652184     0.604721  0.0735368  0.972264
```


## Updates {#Updates}

:::tip

The Julia Compiler is always improving. As such, we recommend using the latest stable version of Julia.

:::

You may check the installed version with:

```julia
pkg> st YAXArrays
```


::: info

With `YAXArrays.jl 0.5` we switched the underlying data type to be a subtype of the DimensionalData.jl types. Therefore the indexing with named dimensions changed to the DimensionalData syntax. See the [`DimensionalData.jl docs`](https://rafaqz.github.io/DimensionalData.jl/stable/).

:::
