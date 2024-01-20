# YAXArrays.jl

*Yet another xarray-like Julia package*

A package for operating on out-of-core labeled arrays, based on stores like NetCDF, Zarr or GDAL.  

!!! info
    - Open datasets from a variety of sources (NetCDF, Zarr, ArchGDAL)
    - Interoperability with other named axis packages through YAXArrayBase
    - Efficient `mapslices(x)` operations on huge multiple arrays, optimized for high-latency data access (object storage, compressed datasets) 

## Installation

In the Julia REPL type:

```julia
using Pkg
Pkg.add("YAXArrays")
```

or 

```julia
] add YAXArrays
```

The `]` character starts the Julia [package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/). Hit backspace key to return to Julia prompt.

You may check the installed version with:

```julia
] st YAXArrays
```

Start using the package:

````julia
using YAXArrays
````

The [YAXArray tutorial](@ref) provides a tutorial explaining how to get started using YAXArrays.

## Quick start

````julia
using YAXArrays
yax = YAXArray(rand(10,20,30))
````