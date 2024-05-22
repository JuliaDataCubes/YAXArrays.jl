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

:::tip

The Julia Compiler is always improving. As such, we recommend using the latest stable
version of Julia.

:::


## Quickstart

```@example quickstart
using YAXArrays
```

You may check the installed version with:

```julia
pkg> st YAXArrays
```

Let's assemble a `YAXArray` with 4 dimensions i.e. time, x,y and a variable dimension with two variables.

```@example quickstart
using YAXArrays, DimensionalData
axlist = (
    Dim{:time}(range(1, 20, length=20)),
    X(range(1, 10, length=10)),
    Y(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"]))
# and the corresponding data.
data = rand(20, 10, 15, 2);
nothing # hide
```

::: info

With `YAXArrays.jl 0.5` we switched the underlying data type to be a subtype of the DimensionalData.jl types. Therefore the indexing with named dimensions changed to the DimensionalData syntax. See the [`DimensionalData.jl docs`](https://rafaqz.github.io/DimensionalData.jl/stable/).

:::

You can also add additional properties via a Dictionary, namely

```@example quickstart
props = Dict(
    "time" => "days",
    "x" => "lon",
    "y" => "lat",
    "var1" => "one of your variables",
    "var2" => "your second variable",
);
nothing # hide
```

And our first YAXArray is built with:

```@ansi quickstart
ds = YAXArray(axlist, data, props)
```

## Getting data from a YAXArray

For axis can be via `.` 

```@example quickstart
ds.X
```

or better yet via `lookup`

```@example quickstart
lookup(ds, :X)
```

note that also the `.data` field can be use

```@example quickstart
lookup(ds, :X).data
```

The data for one variables, i.e. `var1` can be accessed via:

```@ansi quickstart
ds[Variable=At("var1")]
```

and again, you can use the `.data` field to actually get the data.