
# Convert YAXArrays {#Convert-YAXArrays}

This section describes how to convert variables from types of other Julia packages into YAXArrays and vice versa.

::: warning

YAXArrays is designed to work with large datasets that are way larger than the memory. However, most types are designed to work in memory. Those conversions are only possible if the entire dataset fits into memory. In addition, metadata might be lost during conversion.

:::

## Convert `Base.Array` {#Convert-Base.Array}

Convert `Base.Array` to `YAXArray`:

```julia
using YAXArrays

m = rand(5,10)
a = YAXArray(m)
```


```
┌ 5×10 YAXArray{Float64, 2} ┐
├───────────────────────────┴─────────────────────────────────── dims ┐
  ↓ Dim_1 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points,
  → Dim_2 Sampled{Int64} Base.OneTo(10) ForwardOrdered Regular Points
├─────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├─────────────────────────────────────────────────── loaded in memory ┤
  data size: 400.0 bytes
└─────────────────────────────────────────────────────────────────────┘
```


Convert `YAXArray` to `Base.Array`:

```julia
m2 = collect(a.data)
```


```
5×10 Matrix{Float64}:
 0.265797  0.789891  0.611084  0.845983  …  0.918555  0.870826   0.348362
 0.665723  0.241882  0.426519  0.581312     0.949935  0.0214057  0.152534
 0.83556   0.456765  0.197238  0.645758     0.74732   0.652339   0.935631
 0.337926  0.151146  0.673373  0.169284     0.75269   0.166212   0.0358348
 0.594514  0.364288  0.78467   0.830391     0.128204  0.174934   0.0210077
```


## Convert `Raster` {#Convert-Raster}

A `Raster` as defined in [Rasters.jl](https://rafaqz.github.io/Rasters.jl/stable/) has a same supertype of a `YAXArray`, i.e. `AbstractDimArray`, allowing easy conversion between those types:

```julia
using Rasters

lon, lat = X(25:1:30), Y(25:1:30)
time = Ti(2000:2024)
ras = Raster(rand(lon, lat, time))
a = YAXArray(dims(ras), ras.data)
```


```julia
ras2 = Raster(a)
```


## Convert `DimArray` {#Convert-DimArray}

A `DimArray` as defined in [DimensionalData.jl](https://rafaqz.github.io/DimensionalData.jl/dev/dimarrays) has a same supertype of a `YAXArray`, i.e. `AbstractDimArray`, allowing easy conversion between those types.

Convert `DimArray` to `YAXArray`:

```julia
using DimensionalData
using YAXArrayBase

dim_arr = rand(X(1:5), Y(10.0:15.0), metadata = Dict{String, Any}())
a = yaxconvert(YAXArray, dim_arr)
```


```
┌ 5×6 YAXArray{Float64, 2} ┐
├──────────────────────────┴───────────────────────────────── dims ┐
  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,
  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────── loaded in memory ┤
  data size: 240.0 bytes
└──────────────────────────────────────────────────────────────────┘
```


Convert `YAXArray` to `DimArray`:

```julia
dim_arr2 = yaxconvert(DimArray, a)
```


```
┌ 5×6 DimArray{Float64, 2} ┐
├──────────────────────────┴───────────────────────────────── dims ┐
  ↓ X Sampled{Int64} 1:5 ForwardOrdered Regular Points,
  → Y Sampled{Float64} 10.0:1.0:15.0 ForwardOrdered Regular Points
├──────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
└──────────────────────────────────────────────────────────────────┘
 ↓ →  10.0       11.0        12.0        13.0       14.0       15.0
 1     0.862644   0.872575    0.0620649   0.193109   0.475725   0.953391
 2     0.203714   0.770949    0.731779    0.71314    0.687891   0.435994
 3     0.492817   0.718667    0.0702532   0.926096   0.225542   0.100622
 4     0.268675   0.0566881   0.916686    0.973332   0.744521   0.052264
 5     0.540514   0.215973    0.617023    0.796375   0.13205    0.366625
```


::: info

At the moment there is no support to save a DimArray directly into disk as a `NetCDF` or a `Zarr` file.

:::
