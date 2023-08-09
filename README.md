# YAXArrays.jl

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/JuliaDataCubes/YAXArrays.jl/blob/main/LICENSE)
[![][docs-dev-img]][docs-dev-url][![][ci-img]][ci-url] [![][codecov-img]][codecov-url]
[![][coveralls-img]][coveralls-url][![Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/YAXArrays&label=Downloads)](https://pkgs.genieframework.com?packages=YAXArrays)


<img src="docs/src/assets/logo.png" align="right" style="padding-left:10px;" width="150"/>

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://JuliaDataCubes.github.io/YAXArrays.jl/dev/

[codecov-img]: https://codecov.io/gh/JuliaDataCubes/YAXArrays.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaDataCubes/YAXArrays.jl

[ci-img]: https://github.com/JuliaDataCubes/YAXArrays.jl/workflows/CI/badge.svg
[ci-url]: https://github.com/JuliaDataCubes/YAXArrays.jl/actions?query=workflow%3ACI

[coveralls-img]: https://coveralls.io/repos/github/JuliaDataCubes/YAXArrays.jl/badge.svg?branch=master
[coveralls-url]: https://coveralls.io/github/JuliaDataCubes/YAXArrays.jl?branch=master

## What is YAXArrays.jl?
*Yet Another XArray-like Julia Package*

YAXArrays.jl is a package to handle gridded data that is larger than memory. It enables the [DiskArrays.jl](https://github.com/meggart/DiskArrays.jl) package to access the data lazily and provides `map` and `mapCube` to apply user defined functions on arbitrary subsets of the axes. These computations are also easily parallelized either via Distributed or via Threads. 

### Citing YAXArrays
If you use YAXArrays for a scientific publication, please cite the [Zenodo upload](https://doi.org/10.5281/zenodo.7505394) the following way:

```
Fabian Gans, Felix Cremer, Lazaro Alonso, Guido Kraemer, Pavel V. Dimens, Martin Gutwin, Martin,
Francesco Martinuzzi, Daniel E. Pabon-Moreno, Daniel Loos, Markus Zehner, Mohammed Ayoub Chettouh,
Philippe Roy, Qi Zhang, ckrich, Felix Glaser, & linamaes. (2023).
JuliaDataCubes/YAXArrays.jl: v0.5.0 (v0.5.0) Zenodo. https://doi.org/10.5281/zenodo.8121199
```

<details>
  <summary>BibTeX entry:</summary>

```bib
@software{fabian_gans_2023_8121199,
  author       = {Fabian Gans and
                  Felix Cremer and
                  Lazaro Alonso and
                  Guido Kraemer and
                  Pavel V. Dimens and
                  Martin Gutwin and
                  Martin and
                  Francesco Martinuzzi and
                  Daniel E. Pabon-Moreno and
                  Daniel Loos and
                  Markus Zehner and
                  Mohammed Ayoub Chettouh and
                  Philippe Roy and
                  Qi Zhang and
                  ckrich and
                  Felix Glaser and
                  linamaes},
  title        = {JuliaDataCubes/YAXArrays.jl: v0.5.0},
  month        = jul,
  year         = 2023,
  publisher    = {Zenodo},
  version      = {v0.5.0},
  doi          = {10.5281/zenodo.8121199},
  url          = {https://doi.org/10.5281/zenodo.8121199}
}
```
</details>

Cite all versions by using [10.5281/zenodo.7505394](https://doi.org/10.5281/zenodo.7505394).

<details>
  <summary> ℹ️ Switch to DimensionalData ℹ️ </summary>


With `YAXArrays.jl 0.5` we switched the underlying data type to be a subtype of the DimensionalData.jl types. 
Therefore the indexing with named dimensions changed to the DimensionalData syntax. 
See the [DimensionalData.jl docs](https://rafaqz.github.io/DimensionalData.jl/stable/) and the `Switch` to DimensionalData section in our docs.

</details>

# Installation

Install the YAXArrays package:
```julia
julia>]
pkg> add YAXArrays
```

You may check the installed version with:
```julia
] st YAXArrays
```

Start using the package:
```julia
using YAXArrays
```

## Quick start

Let's assemble a `YAXArray` with 4 dimensions i.e. time, x,y and a variable dimension with two variables.

```julia
using YAXArrays, DimensionalData
axlist = (
    Dim{:time}(range(1, 20, length=20)),
    X(range(1, 10, length=10)),
    Y(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"]))
```
and the corresponding data.
```julia
data = rand(20, 10, 15, 2)
```

You might also add additional properties via a Dictionary, namely

```julia
props = Dict(
    "time" => "days",
    "x" => "lon",
    "y" => "lat",
    "var1" => "one of your variables",
    "var2" => "your second variable",
)
```

And our first YAXArray is built with:

```julia
ds = YAXArray(axlist, data, props)
```
```
20×10×15×2 YAXArray{Float64,4} with dimensions: 
  Dim{:time} Sampled{Float64} 1.0:1.0:20.0 ForwardOrdered Regular Points,
  X Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  Y Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points,
  Dim{:Variable} Categorical{String} String["var1", "var2"] ForwardOrdered
Total size: 46.88 KB
```

## Getting data back from a YAXArray

For axis can be via `.` 

```julia
ds.X
```
```
X Sampled{Float64} ForwardOrdered Regular Points
wrapping: 1.0:1.0:10.0
```

or better yet via `lookup`

```julia
lookup(ds, :X)
```
```
Sampled{Float64} ForwardOrdered Regular Points
wrapping: 1.0:1.0:10.0
```

note that also the `.data` field can be use
```julia
lookup(ds, :X).data
```
```
1.0:1.0:10.0
```

The data for one variables, i.e. `var1` can be accessed via:

```julia
ds[Variable=At("var1")]
```
```
20×10×15 YAXArray{Float64,3} with dimensions: 
  Dim{:time} Sampled{Float64} 1.0:1.0:20.0 ForwardOrdered Regular Points,
  X Sampled{Float64} 1.0:1.0:10.0 ForwardOrdered Regular Points,
  Y Sampled{Float64} 1.0:0.2857142857142857:5.0 ForwardOrdered Regular Points
Total size: 23.44 KB
```
and again, you can use the `.data` field to actually get the data.


For more please take a look at the documentation. 
