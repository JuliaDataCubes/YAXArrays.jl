
# Write YAXArrays and Datasets {#Write-YAXArrays-and-Datasets}

Create an example Dataset:

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


## Write Zarr {#Write-Zarr}

Save a single YAXArray to a directory:

```julia
using Zarr
savecube(ds.tos, "tos.zarr", driver=:zarr)
```


Save an entire Dataset to a directory:

```julia
savedataset(ds, path="ds.zarr", driver=:zarr)
```


### zarr compression {#zarr-compression}

Save a dataset to Zarr format with compression:

```julia
n = 9 # compression level, number between 0 (no compression) and 9 (max compression)
compression = Zarr.BloscCompressor(; clevel=n)

savedataset(ds; path="ds_c.zarr", driver=:zarr, compressor=compression)
```


More on [Zarr Compressors](https://juliaio.github.io/Zarr.jl/latest/reference/#Compressors). Also, if you use this option and don&#39;t notice a significant improvement, please feel free to open an issue or start a discussion. 

## Write NetCDF {#Write-NetCDF}

Save a single YAXArray to a directory:

```julia
using NetCDF
savecube(ds.tos, "tos.nc", driver=:netcdf)
```


Save an entire Dataset to a directory:

```julia
savedataset(ds, path="ds.nc", driver=:netcdf)
```


### netcdf compression {#netcdf-compression}

Save a dataset to NetCDF format with compression:

```julia
n = 7 # compression level, number between 0 (no compression) and 9 (max compression)
savedataset(ds, path="ds_c.nc", driver=:netcdf, compress=n)
```


Comparing it to the default saved file

```julia
ds_info = stat("ds.nc")
ds_c_info = stat("ds_c.nc")
println("File size: ", "default: ", ds_info.size, " bytes", ", compress: ", ds_c_info.size, " bytes")
```


```
File size: default: 2963860 bytes, compress: 1159916 bytes
```


## Overwrite a Dataset {#Overwrite-a-Dataset}

If a path already exists, an error will be thrown. Set `overwrite=true` to delete the existing dataset

```julia
savedataset(ds, path="ds.zarr", driver=:zarr, overwrite=true)
```


::: danger

Again, setting `overwrite` will delete all your previous saved data.

:::

Look at the doc string for more information
<details class='jldocstring custom-block' open>
<summary><a id='YAXArrays.Datasets.savedataset' href='#YAXArrays.Datasets.savedataset'><span class="jlbinding">YAXArrays.Datasets.savedataset</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
savedataset(ds::Dataset; path= "", persist=nothing, overwrite=false, append=false, skeleton=false, backend=:all, driver=backend, max_cache=5e8, writefac=4.0)
```


Saves a Dataset into a file at `path` with the format given by `driver`, i.e., `driver=:netcdf` or `driver=:zarr`.

::: warning Warning

`overwrite=true`, deletes ALL your data and it will create a new file.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/JuliaDataCubes/YAXArrays.jl/blob/ef6d4acd60d9eaed889255a7c34fb8e3b9ff3685/src/DatasetAPI/Datasets.jl#L662-L670" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Append to a Dataset {#Append-to-a-Dataset}

New variables can be added to an existing dataset using the `append=true` keyword. 

```julia
ds2 = Dataset(z = YAXArray(rand(10,20,5)))
savedataset(ds2, path="ds.zarr", backend=:zarr, append=true)
```


```julia
julia> open_dataset("ds.zarr", driver=:zarr)
```

```ansi
YAXArray Dataset
Shared Axes:
[90mNone[39m
[93mVariables with additional axes:[39m
[90m  Additional Axes: [39m
  ([38;5;209m↓ [39m[38;5;209mlon [39m Sampled{Float64} [38;5;209m1.0:2.0:359.0[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mlat [39m Sampled{Float64} [38;5;32m-79.5:1.0:89.5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mtime[39m Sampled{CFTime.DateTime360Day} [38;5;81m[CFTime.DateTime360Day(2001-01-16T00:00:00), …, CFTime.DateTime360Day(2002-12-16T00:00:00)][39m [38;5;244mForwardOrdered[39m [38;5;244mIrregular[39m [38;5;244mPoints[39m)
[94m  Variables: [39m
  tos

[90m  Additional Axes: [39m
  ([38;5;209m↓ [39m[38;5;209mDim_1[39m Sampled{Int64} [38;5;209m1:1:10[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mDim_2[39m Sampled{Int64} [38;5;32m1:1:20[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mDim_3[39m Sampled{Int64} [38;5;81m1:1:5[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m)
[94m  Variables: [39m
  z

[93mProperties: [39mDict{String, Any}("cmor_version" => 0.96, "references" => "Dufresne et al, Journal of Climate, 2015, vol XX, p 136", "realization" => 1, "contact" => "Sebastien Denvil, sebastien.denvil@ipsl.jussieu.fr", "Conventions" => "CF-1.0", "history" => "YYYY/MM/JJ: data generated; YYYY/MM/JJ+1 data transformed  At 16:37:23 on 01/11/2005, CMOR rewrote data to comply with CF standards and IPCC Fourth Assessment requirements", "table_id" => "Table O1 (13 November 2004)", "source" => "IPSL-CM4_v1 (2003) : atmosphere : LMDZ (IPSL-CM4_IPCC, 96x71x19) ; ocean ORCA2 (ipsl_cm4_v1_8, 2x2L31); sea ice LIM (ipsl_cm4_v", "title" => "IPSL  model output prepared for IPCC Fourth Assessment SRES A2 experiment", "experiment_id" => "SRES A2 experiment"…)
```


## Save Skeleton {#Save-Skeleton}

Sometimes one merely wants to create a datacube  &quot;Skeleton&quot; on disk and gradually fill it with data. Here we make use of `FillArrays` to create a `YAXArray` and write only the axis data and array metadata to disk, while no actual array data is copied:

```julia
using YAXArrays, Zarr, FillArrays
```


create the `Zeros` array

```julia
julia> a = YAXArray(Zeros(Union{Missing, Float32},  5, 4, 5))
```

```ansi
[90m┌ [39m[38;5;209m5[39m×[38;5;32m4[39m×[38;5;81m5[39m YAXArray{Union{Missing, Float32}, 3}[90m ┐[39m
[90m├────────────────────────────────────────────┴─────────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mDim_1[39m Sampled{Int64} [38;5;209mBase.OneTo(5)[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;32m→ [39m[38;5;32mDim_2[39m Sampled{Int64} [38;5;32mBase.OneTo(4)[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m,
  [38;5;81m↗ [39m[38;5;81mDim_3[39m Sampled{Int64} [38;5;81mBase.OneTo(5)[39m [38;5;244mForwardOrdered[39m [38;5;244mRegular[39m [38;5;244mPoints[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{String, Any}()
[90m├──────────────────────────────────────────────────────────── loaded in memory ┤[39m
  data size: 400.0 bytes
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
```


Now, save to disk with

```julia
r = savecube(a, "skeleton.zarr", layername="skeleton", driver=:zarr, skeleton=true, overwrite=true)
```


::: warning

`overwrite=true` will delete your previous `.zarr` file before creating a new one.

:::

Note also that if `layername="skeleton"` is not provided then the `default name` for the cube variable will be `layer`.

Now, we check that all the values are `missing`

```julia
all(ismissing, r[:,:,:])
```


```
true
```


If using `FillArrays` is not possible, using the `zeros` function works as well, though it does allocate the array in memory.

::: info

The `skeleton` argument is also available for `savedataset`. 

:::

Using the toy array defined above we can do 

```julia
ds = Dataset(skeleton=a) # skeleton will the variable name
```


```
YAXArray Dataset
Shared Axes: 
  (↓ Dim_1 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points,
  → Dim_2 Sampled{Int64} Base.OneTo(4) ForwardOrdered Regular Points,
  ↗ Dim_3 Sampled{Int64} Base.OneTo(5) ForwardOrdered Regular Points)

Variables: 
skeleton


```


```julia
ds_s = savedataset(ds, path="skeleton.zarr", driver=:zarr, skeleton=true, overwrite=true)
```


## Update values of `dataset` {#Update-values-of-dataset}

Now, we show how to start updating the array values. In order to do it we need to open the dataset first with writing `w` rights as follows:

```julia
ds_open = zopen("skeleton.zarr", "w")
ds_array = ds_open["skeleton"]
```


```
ZArray{Float32} of size 5 x 4 x 5
```


and then we simply update values by indexing them where necessary

```julia
ds_array[:,:,1] = rand(Float32, 5, 4) # this will update values directly into disk!
```


```
5×4 Matrix{Float32}:
 0.166209  0.167822  0.811004  0.739005
 0.239648  0.971882  0.234606  0.456544
 0.514822  0.383811  0.915756  0.156314
 0.804614  0.729526  0.367598  0.47125
 0.200561  0.408587  0.359569  0.117686
```


we can verify is this working by loading again directly from disk

```julia
ds_open = open_dataset("skeleton.zarr")
ds_array = ds_open["skeleton"]
ds_array.data[:,:,1]
```


```
5×4 Matrix{Union{Missing, Float32}}:
 0.166209  0.167822  0.811004  0.739005
 0.239648  0.971882  0.234606  0.456544
 0.514822  0.383811  0.915756  0.156314
 0.804614  0.729526  0.367598  0.47125
 0.200561  0.408587  0.359569  0.117686
```


indeed, those entries had been updated.
