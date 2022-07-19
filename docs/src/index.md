# YAXArrays.jl

*Yet another xarray-like Julia package*

A package for operating on out-of-core labeled arrays, based on stores like NetCDF, Zarr or GDAL.  

## Package Features

- open datasets from a variety of sources (NetCDF, Zarr, ArchGDAL)
- interoperability with other named axis packages through YAXArrayBase
- efficient `mapslices(x)` operations on huge multiple arrays, optimized for high-latency data access (object storage, compressed datasets) 

The [YAXArray tutorial](@ref) provides a tutorial explaining how to get started using YAXArrays.

## Manual Outline

```@contents
Pages = [
    "tutorials/tutorial.md",
    "howtos/howtos.md",
    "exp/exp.md"
]
Depth = 2
```
## Library Outline

```@contents
Pages = ["lib/public.md", "lib/internals.md"]
```

### [Index](@id main-index)

```@index
Pages = ["lib/public.md"]
``` -->