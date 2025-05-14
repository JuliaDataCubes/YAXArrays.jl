
# Read YAXArrays and Datasets {#Read-YAXArrays-and-Datasets}

This section describes how to read files, URLs, and directories into YAXArrays and datasets.

## open_dataset {#open_dataset}

The usual method for reading any format is using this function. See its `docstring` for more information.
<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.open_dataset' href='#YAXArrays.Datasets.open_dataset'><span class="jlbinding">YAXArrays.Datasets.open_dataset</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
open_dataset(g; skip_keys=(), driver=:all)
```


Open the dataset at `g` with the given `driver`. The default driver will search for available drivers and tries to detect the useable driver from the filename extension.

**Keyword arguments**
- `skip_keys` are passed as symbols, i.e., `skip_keys = (:a, :b)`
  
- `driver=:all`, common options are `:netcdf` or `:zarr`.
  

Example:

```julia
ds = open_dataset(f, driver=:zarr, skip_keys = (:c,))
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L420-L436" target="_blank" rel="noreferrer">source</a></Badge>

</details>


Now, let&#39;s explore different examples.

### Read Zarr {#Read-Zarr}

Open a Zarr store as a `Dataset`:

```julia
using YAXArrays
using Zarr
path="gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/"
store = zopen(path, consolidated=true)
ds = open_dataset(store)
```


```
YAXArray Dataset
Shared Axes: 
None
Variables: 
height

Variables with additional axes:
  Additional Axes: 
  (↓ lon  Sampled{Float64} 0.0:0.9375:359.0625 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} [-89.28422753251364, -88.35700351866494, …, 88.35700351866494, 89.28422753251364] ForwardOrdered Irregular Points,
  ↗ time Sampled{DateTime} [2015-01-01T03:00:00, …, 2101-01-01T00:00:00] ForwardOrdered Irregular Points)
  Variables: 
  tas

Properties: Dict{String, Any}("initialization_index" => 1, "realm" => "atmos", "variable_id" => "tas", "external_variables" => "areacella", "branch_time_in_child" => 60265.0, "data_specs_version" => "01.00.30", "history" => "2019-07-21T06:26:13Z ; CMOR rewrote data to be consistent with CMIP6, CF-1.7 CMIP-6.2 and CF standards.", "forcing_index" => 1, "parent_variant_label" => "r1i1p1f1", "table_id" => "3hr"…)

```


We can set `path` to a URL, a local directory, or in this case to a cloud object storage path.

A zarr store may contain multiple arrays. Individual arrays can be accessed using subsetting:

```julia
ds.tas
```


```
┌ 384×192×251288 YAXArray{Float32, 3} ┐
├─────────────────────────────────────┴────────────────────────────────── dims ┐
  ↓ lon  Sampled{Float64} 0.0:0.9375:359.0625 ForwardOrdered Regular Points,
  → lat  Sampled{Float64} [-89.28422753251364, -88.35700351866494, …, 88.35700351866494, 89.28422753251364] ForwardOrdered Irregular Points,
  ↗ time Sampled{DateTime} [2015-01-01T03:00:00, …, 2101-01-01T00:00:00] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 10 entries:
  "units"         => "K"
  "history"       => "2019-07-21T06:26:13Z altered by CMOR: Treated scalar dime…
  "name"          => "tas"
  "cell_methods"  => "area: mean time: point"
  "cell_measures" => "area: areacella"
  "long_name"     => "Near-Surface Air Temperature"
  "coordinates"   => "height"
  "standard_name" => "air_temperature"
  "_FillValue"    => 1.0f20
  "comment"       => "near-surface (usually, 2 meter) air temperature"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 69.02 GB
└──────────────────────────────────────────────────────────────────────────────┘
```


### Read NetCDF {#Read-NetCDF}

Open a NetCDF file as a `Dataset`:

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


A NetCDF file may contain multiple arrays. Individual arrays can be accessed using subsetting:

```julia
ds.tos
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


Please note that netCDF4 uses HDF5 which is not thread-safe in Julia. Add manual [locks](https://docs.julialang.org/en/v1/manual/multi-threading/#man-using-locks) in your own code to avoid any data-race:

```julia
my_lock = ReentrantLock()
Threads.@threads for i in 1:10
    @lock my_lock @info ds.tos[1, 1, 1]
end
```


```
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
[ Info: missing
```


This code will ensure that the data is only accessed by one thread at a time, i.e. making it actual single-threaded but thread-safe.

### Read GDAL (GeoTIFF, GeoJSON) {#Read-GDAL-GeoTIFF,-GeoJSON}

All GDAL compatible files can be read as a `YAXArrays.Dataset` after loading [ArchGDAL](https://yeesian.com/ArchGDAL.jl/latest/):

```julia
using YAXArrays
using ArchGDAL
using Downloads: download

path = download("https://github.com/yeesian/ArchGDALDatasets/raw/307f8f0e584a39a050c042849004e6a2bd674f99/gdalworkshop/world.tif", "world.tif")
ds = open_dataset(path)
```


```
YAXArray Dataset
Shared Axes: 
  (↓ X Sampled{Float64} -180.0:0.17578125:179.82421875 ForwardOrdered Regular Points,
  → Y Sampled{Float64} 90.0:-0.17578125:-89.82421875 ReverseOrdered Regular Points)

Variables: 
Blue, Green, Red

Properties: Dict{String, Any}("projection" => "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AXIS[\"Latitude\",NORTH],AXIS[\"Longitude\",EAST],AUTHORITY[\"EPSG\",\"4326\"]]")

```


### Load data into memory {#Load-data-into-memory}

For datasets or variables that could fit in RAM, you might want to load them completely into memory. This can be done using the `readcubedata` function. As an example, let&#39;s use the NetCDF workflow; the same should be true for other cases.

#### readcubedata {#readcubedata}

:::tabs

== single variable

```julia
readcubedata(ds.tos)
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
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 2.8 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


== with the `:` operator

```julia
ds.tos[:, :, :]
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
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 2.8 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


In this case, you should know in advance how many dimensions there are and how long they are, which shouldn&#39;t be hard to determine since this information is already displayed when querying such variables.

== Complete Dataset

```julia
ds_loaded = readcubedata(ds)
ds_loaded["tos"] # Load the variable of interest; the loaded status is shown for each variable.
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
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 2.8 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


:::

Note how the loading status changes from `loaded lazily` to `loaded in memory`.

## open_mfdataset {#open_mfdataset}

There are situations when we would like to open and concatenate a list of dataset paths along a certain dimension. For example, to concatenate a list of `NetCDF` files along a new `time` dimension, one can use:

::: details creation of NetCDF files

```julia
using YAXArrays, NetCDF, Dates
using YAXArrays: YAXArrays as YAX

dates_1 = [Date(2020, 1, 1) + Dates.Day(i) for i in 1:3]
dates_2 = [Date(2020, 1, 4) + Dates.Day(i) for i in 1:3]

a1 = YAXArray((lon(1:5), lat(1:7)), rand(5, 7))
a2 = YAXArray((lon(1:5), lat(1:7)), rand(5, 7))

a3 = YAXArray((lon(1:5), lat(1:7), YAX.time(dates_1)), rand(5, 7, 3))
a4 = YAXArray((lon(1:5), lat(1:7), YAX.time(dates_2)), rand(5, 7, 3))

savecube(a1, "a1.nc")
savecube(a2, "a2.nc")
savecube(a3, "a3.nc")
savecube(a4, "a4.nc")
```


```
┌ 5×7×3 YAXArray{Float64, 3} ┐
├────────────────────────────┴─────────────────────────────────────────── dims ┐
  ↓ lon  Sampled{Int64} 1:5 ForwardOrdered Regular Points,
  → lat  Sampled{Int64} 1:7 ForwardOrdered Regular Points,
  ↗ time Sampled{Date} [2020-01-05, …, 2020-01-07] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 840.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


:::

### along a new dimension {#along-a-new-dimension}

```julia
using YAXArrays, NetCDF, Dates
using YAXArrays: YAXArrays as YAX
import DimensionalData as DD

files = ["a1.nc", "a2.nc"]

dates_read = [Date(2024, 1, 1) + Dates.Day(i) for i in 1:2]
ds = open_mfdataset(DD.DimArray(files, YAX.time(dates_read)))
```


```
YAXArray Dataset
Shared Axes: 
  (↓ lon  Sampled{Int64} 1:1:5 ForwardOrdered Regular Points,
  → lat  Sampled{Int64} 1:1:7 ForwardOrdered Regular Points,
  ↗ time Sampled{Date} [Date("2024-01-02"), Date("2024-01-03")] ForwardOrdered Irregular Points)

Variables: 
layer


```


and even opening files along a new `Time` dimension that already have a `time` dimension

```julia
files = ["a3.nc", "a4.nc"]
ds = open_mfdataset(DD.DimArray(files, YAX.Time(dates_read)))
```


```
YAXArray Dataset
Shared Axes: 
  (↓ lon  Sampled{Int64} 1:1:5 ForwardOrdered Regular Points,
  → lat  Sampled{Int64} 1:1:7 ForwardOrdered Regular Points,
  ↗ time Sampled{DateTime} [2020-01-02T00:00:00, …, 2020-01-04T00:00:00] ForwardOrdered Irregular Points,
  ⬔ Time Sampled{Date} [Date("2024-01-02"), Date("2024-01-03")] ForwardOrdered Irregular Points)

Variables: 
layer


```


Note that opening along a new dimension name without specifying values also works; however, it defaults to `1:length(files)` for the dimension values.

```julia
files = ["a1.nc", "a2.nc"]
ds = open_mfdataset(DD.DimArray(files, YAX.time))
```


```
YAXArray Dataset
Shared Axes: 
  (↓ lon  Sampled{Int64} 1:1:5 ForwardOrdered Regular Points,
  → lat  Sampled{Int64} 1:1:7 ForwardOrdered Regular Points,
  ↗ time Sampled{Int64} 1:2 ForwardOrdered Regular Points)

Variables: 
layer


```


### along a existing dimension {#along-a-existing-dimension}

Another use case is when we want to open files along an existing dimension. In this case, `open_mfdataset` will concatenate the paths along the specified dimension

```julia
using YAXArrays, NetCDF, Dates
using YAXArrays: YAXArrays as YAX
import DimensionalData as DD

files = ["a3.nc", "a4.nc"]

ds = open_mfdataset(DD.DimArray(files, YAX.time()))
```


```
YAXArray Dataset
Shared Axes: 
  (↓ lon  Sampled{Int64} 1:1:5 ForwardOrdered Regular Points,
  → lat  Sampled{Int64} 1:1:7 ForwardOrdered Regular Points,
  ↗ time Sampled{DateTime} [2020-01-02T00:00:00, …, 2020-01-07T00:00:00] ForwardOrdered Irregular Points)

Variables: 
layer


```


where the contents of the `time` dimension are the merged values from both files

```julia
ds["time"]
```


```
time Sampled{DateTime} ForwardOrdered Irregular DimensionalData.Dimensions.Lookups.Points
wrapping: 6-element Vector{DateTime}:
 2020-01-02T00:00:00
 2020-01-03T00:00:00
 2020-01-04T00:00:00
 2020-01-05T00:00:00
 2020-01-06T00:00:00
 2020-01-07T00:00:00
```


providing us with a wide range of options to work with.
