
# Select YAXArrays and Datasets {#Select-YAXArrays-and-Datasets}

The dimensions or axes of an `YAXArray` are named making it easier to subset or query certain ranges of an array. Let&#39;s open an example `Dataset` used to select certain elements:

```julia
using YAXArrays
using NetCDF
using Downloads: download

path = download("https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc", "example.nc")
ds = open_dataset(path)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points)

Variables: 
tos

Properties: Dict{String, Any}("cmor_version" => 0.96f0, "references" => "Dufresne et al, Journal of Climate, 2015, vol XX, p 136", "realization" => 1, "Conventions" => "CF-1.0", "contact" => "Sebastien Denvil, sebastien.denvil@ipsl.jussieu.fr", "history" => "YYYY/MM/JJ: data generated; YYYY/MM/JJ+1 data transformed  At 16:37:23 on 01/11/2005, CMOR rewrote data to comply with CF standards and IPCC Fourth Assessment requirements", "table_id" => "Table O1 (13 November 2004)", "source" => "IPSL-CM4_v1 (2003) : atmosphere : LMDZ (IPSL-CM4_IPCC, 96x71x19) ; ocean ORCA2 (ipsl_cm4_v1_8, 2x2L31); sea ice LIM (ipsl_cm4_v", "title" => "IPSL  model output prepared for IPCC Fourth Assessment SRES A2 experiment", "experiment_id" => "SRES A2 experiment"…)

```


## Select a YAXArray {#Select-a-YAXArray}

Get the sea surface temperature of the `Dataset`:

```julia
tos = ds.tos
```


```
┌ 180×170×24 YAXArray{Union{Missing, Float32}, 3} ┐
├─────────────────────────────────────────────────┴────────────────────── dims ┐
  ↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 2.8 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


which is the same as:

```julia
tos = ds.cubes[:tos]
```


```
┌ 180×170×24 YAXArray{Union{Missing, Float32}, 3} ┐
├─────────────────────────────────────────────────┴────────────────────── dims ┐
  ↓ lon  Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 2.8 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


## Select elements {#Select-elements}

Using positional integer indexing:

```julia
tos[lon = 1, lat = 1]
```


```
┌ 24-element YAXArray{Union{Missing, Float32}, 1} ┐
├─────────────────────────────────────────────────┴────────────────────── dims ┐
  ↓ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 96.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


Same but using named indexing:

```julia
tos[lon = At(1), lat = At(-79.5)]
```


```
┌ 24-element YAXArray{Union{Missing, Float32}, 1} ┐
├─────────────────────────────────────────────────┴────────────────────── dims ┐
  ↓ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 96.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


Using special types:

```julia
using CFTime
time1 = DateTime360Day(2001,01,16)
tos[time = At(time1)]
```


```
┌ 180×170 YAXArray{Union{Missing, Float32}, 2} ┐
├──────────────────────────────────────────────┴──────────────── dims ┐
  ↓ lon Sampled{Float64} 1.0:2.0:359.0 ForwardOrdered Regular Points,
  → lat Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points
├─────────────────────────────────────────────────────────────────────┴ metadata ┐
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├───────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 119.53 KB
└────────────────────────────────────────────────────────────────────────────────┘
```


## Select ranges {#Select-ranges}

Here we subset an interval of a dimension using positional integer indexing.

```julia
tos[lon = 1:10, lat = 1:10]
```


```
┌ 10×10×24 YAXArray{Union{Missing, Float32}, 3} ┐
├───────────────────────────────────────────────┴──────────────────────── dims ┐
  ↓ lon  Sampled{Float64} 1.0:2.0:19.0 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} -79.5:1.0:-70.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 9.38 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


Same but using named indexing:

```julia
tos[lon = At(1.0:2:19), lat = At(-79.5:1:-70.5)]
```


```
┌ 10×10×24 YAXArray{Union{Missing, Float32}, 3} ┐
├───────────────────────────────────────────────┴──────────────────────── dims ┐
  ↓ lon  Sampled{Float64} [1.0, 3.0, …, 17.0, 19.0] ForwardOrdered Irregular Points,
  → lat  Sampled{Float64} [-79.5, -78.5, …, -71.5, -70.5] ForwardOrdered Irregular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 9.38 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


Read more about the `At` selector in the package `DimensionalData`. Get values within a tolerances:

```julia
tos[lon = At(1:10; atol = 1)]
```


```
┌ 10×170×24 YAXArray{Union{Missing, Float32}, 3} ┐
├────────────────────────────────────────────────┴─────────────────────── dims ┐
  ↓ lon  Sampled{Float64} [1.0, 1.0, …, 9.0, 9.0] ForwardOrdered Irregular Points,
  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 159.38 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


## Closed and open intervals {#Closed-and-open-intervals}

Although a `Between(a,b)` function is available in `DimensionalData`, is recommended to use instead the `a .. b` notation:

```julia
tos[lon = 90 .. 180]
```


```
┌ 45×170×24 YAXArray{Union{Missing, Float32}, 3} ┐
├────────────────────────────────────────────────┴─────────────────────── dims ┐
  ↓ lon  Sampled{Float64} 91.0:2.0:179.0 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTime360Day} [CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 717.19 KB
└──────────────────────────────────────────────────────────────────────────────┘
```


This describes a closed interval in which all points were included.  More selectors from DimensionalData are available, such as `Touches`, `Near`, `Where` and `Contains`.

```julia
using IntervalSets
```


```julia
julia> tos[lon = OpenInterval(90, 180)]
```

```ansi
[90m┌ [39m[38;5;209m45[39m×[38;5;32m170[39m×[38;5;81m24[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├────────────────────────────────────────────────┴─────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Float64} [38;5;209m91.0:2.0:179.0[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Float64} [38;5;32m-79.5:1.0:89.5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{CFTime.DateTime360Day} [38;5;81m[CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)][39m [38;5;244mForwardOrdered[39m [38;5;244mIrregular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 717.19 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


```julia
julia> tos[lon = ClosedInterval(90, 180)]
```

```ansi
[90m┌ [39m[38;5;209m45[39m×[38;5;32m170[39m×[38;5;81m24[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├────────────────────────────────────────────────┴─────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Float64} [38;5;209m91.0:2.0:179.0[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Float64} [38;5;32m-79.5:1.0:89.5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{CFTime.DateTime360Day} [38;5;81m[CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)][39m [38;5;244mForwardOrdered[39m [38;5;244mIrregular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 717.19 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


```julia
julia> tos[lon =Interval{:open,:closed}(90,180)]
```

```ansi
[90m┌ [39m[38;5;209m45[39m×[38;5;32m170[39m×[38;5;81m24[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├────────────────────────────────────────────────┴─────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Float64} [38;5;209m91.0:2.0:179.0[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Float64} [38;5;32m-79.5:1.0:89.5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{CFTime.DateTime360Day} [38;5;81m[CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)][39m [38;5;244mForwardOrdered[39m [38;5;244mIrregular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 717.19 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


```julia
julia> tos[lon =Interval{:closed,:open}(90,180)]
```

```ansi
[90m┌ [39m[38;5;209m45[39m×[38;5;32m170[39m×[38;5;81m24[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├────────────────────────────────────────────────┴─────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Float64} [38;5;209m91.0:2.0:179.0[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Float64} [38;5;32m-79.5:1.0:89.5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{CFTime.DateTime360Day} [38;5;81m[CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)][39m [38;5;244mForwardOrdered[39m [38;5;244mIrregular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any} with 10 entries:
  "units"          => "K"
  "missing_value"  => 1.0f20
  "history"        => " At   16:37:23 on 01/11/2005: CMOR altered the data in t…
  "cell_methods"   => "time: mean (interval: 30 minutes)"
  "name"           => "tos"
  "long_name"      => "Sea Surface Temperature"
  "original_units" => "degC"
  "standard_name"  => "sea_surface_temperature"
  "_FillValue"     => 1.0f20
  "original_name"  => "sosstsst"
[90m├─────────────────────────────────────────────────────────────── loaded lazily ┤[39m
  data size: 717.19 KB
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


See tutorials for use cases.

## Get a dimension {#Get-a-dimension}

Get values, .e.g., axis tick labels, of a dimension that can be used for subseting:

```julia
collect(tos.lat)
```


```
┌ 170-element DimArray{Float64, 1} ┐
├──────────────────────────────────┴──────────────────────────── dims ┐
  ↓ lat Sampled{Float64} -79.5:1.0:89.5 ForwardOrdered Regular Points
└─────────────────────────────────────────────────────────────────────┘
 -79.5  -79.5
 -78.5  -78.5
 -77.5  -77.5
 -76.5  -76.5
 -75.5  -75.5
 -74.5  -74.5
   ⋮    
  85.5   85.5
  86.5   86.5
  87.5   87.5
  88.5   88.5
  89.5   89.5
```


These values are defined as lookups in the package `DimensionalData`:

```julia
lookup(tos, :lon)
```


```
Sampled{Float64} ForwardOrdered Regular DimensionalData.Dimensions.Lookups.Points
wrapping: 1.0:2.0:359.0
```


which is equivalent to:

```julia
tos.lon.val
```


```
Sampled{Float64} ForwardOrdered Regular DimensionalData.Dimensions.Lookups.Points
wrapping: 1.0:2.0:359.0
```

