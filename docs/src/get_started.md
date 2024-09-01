# Getting Started

## Installation

Install [Julia v1.10 or above](https://julialang.org/downloads/). YAXArrays.jl is available through the Julia package manager. You can enter it by pressing `]` in the REPL and then typing

```julia
pkg> add YAXArrays
```

Alternatively, you can also do

```julia
import Pkg; Pkg.add("YAXArrays")
```

## Quickstart

Create a simple array from random numbers given the size of each dimension or axis:

```@example quickstart
using YAXArrays

a = YAXArray(rand(2,3))
```

Assemble a more complex `YAXArray` with 4 dimensions, i.e. time, x, y and a variable type:

```@example quickstart
using DimensionalData

# axes or dimensions with name and tick values
axlist = (
    Dim{:time}(range(1, 20, length=20)),
    X(range(1, 10, length=10)),
    Y(range(1, 5, length=15)),
    Dim{:variable}(["temperature", "precipitation"])
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

Get the temperature map at the first point in time:

```@example quickstart
a2[variable=At("temperature"), time=1].data
```

Get more details at the [select page](./UserGuide/select)

## Updates

:::tip

The Julia Compiler is always improving. As such, we recommend using the latest stable
version of Julia.

:::

You may check the installed version with:

```julia
pkg> st YAXArrays
```

::: info

With `YAXArrays.jl 0.5` we switched the underlying data type to be a subtype of the DimensionalData.jl types. Therefore the indexing with named dimensions changed to the DimensionalData syntax. See the [`DimensionalData.jl docs`](https://rafaqz.github.io/DimensionalData.jl/stable/).

:::