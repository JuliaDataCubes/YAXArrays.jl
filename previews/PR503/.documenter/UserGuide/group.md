
# Group YAXArrays and Datasets {#Group-YAXArrays-and-Datasets}

The following examples will use the `groupby` function to calculate temporal and spatial averages.

```julia
using YAXArrays, DimensionalData
using YAXArrays: YAXArrays as YAX
using NetCDF
using Downloads
using Dates
using Statistics
```


### Seasonal Averages from Time Series of Monthly Means {#Seasonal-Averages-from-Time-Series-of-Monthly-Means}

The following reproduces the example in [xarray](https://docs.xarray.dev/en/stable/examples/monthly-means.html) by [Joe Hamman](https://github.com/jhamman/).

Where the goal is to calculate the seasonal average. And in order to do this properly, is necessary to calculate the weighted average considering that each month has a different number of days.

### Download the data {#Download-the-data}

```julia
url_path = "https://github.com/pydata/xarray-data/raw/master/rasm.nc"
filename = Downloads.download(url_path, "rasm.nc")
ds_o = Cube(filename)
```


```
┌ 275×205×36 YAXArray{Float64, 3} ┐
├─────────────────────────────────┴────────────────────────────────────── dims ┐
  ↓ x    Sampled{Int64} 1:275 ForwardOrdered Regular Points,
  → y    Sampled{Int64} 1:205 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTimeNoLeap} [CFTime.DateTimeNoLeap(1980-09-16T12:00:00), …, CFTime.DateTimeNoLeap(1983-08-17T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 7 entries:
  "units"          => "C"
  "coordinates"    => "yc xc"
  "name"           => "Tair"
  "long_name"      => "Surface air temperature"
  "type_preferred" => "double"
  "_FillValue"     => 9.96921e36
  "time_rep"       => "instantaneous"
├─────────────────────────────────────────────────────────────── loaded lazily ┤
  data size: 15.48 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


::: warning

The following rebuild should not be necessary in the future, plus is unpractical to use for large data sets. Out of memory groupby currently is work in progress. Related to https://github.com/rafaqz/DimensionalData.jl/issues/642

:::

```julia
_FillValue = ds_o.properties["_FillValue"]
ds = replace(ds_o[:,:,:], _FillValue => NaN) # load into memory and replace _FillValue by NaN
```


```
┌ 275×205×36 YAXArray{Float64, 3} ┐
├─────────────────────────────────┴────────────────────────────────────── dims ┐
  ↓ x    Sampled{Int64} 1:275 ForwardOrdered Regular Points,
  → y    Sampled{Int64} 1:205 ForwardOrdered Regular Points,
  ↗ time Sampled{CFTime.DateTimeNoLeap} [CFTime.DateTimeNoLeap(1980-09-16T12:00:00), …, CFTime.DateTimeNoLeap(1983-08-17T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any} with 7 entries:
  "units"          => "C"
  "coordinates"    => "yc xc"
  "name"           => "Tair"
  "long_name"      => "Surface air temperature"
  "type_preferred" => "double"
  "_FillValue"     => 9.96921e36
  "time_rep"       => "instantaneous"
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 15.48 MB
└──────────────────────────────────────────────────────────────────────────────┘
```


## GroupBy: seasons {#GroupBy:-seasons}

::: details function weighted_seasons(ds) ... end

```julia
function weighted_seasons(ds)
    # calculate weights 
    tempo = dims(ds, :time)
    month_length = YAXArray((tempo,), daysinmonth.(tempo))
    g_tempo = groupby(month_length, YAX.time => seasons(; start=December))
    sum_days = sum.(g_tempo, dims=:time)
    weights = map(./, g_tempo, sum_days)
    # unweighted seasons
    g_ds = groupby(ds, YAX.time => seasons(; start=December))
    mean_g = mean.(g_ds, dims=:time)
    mean_g = dropdims.(mean_g, dims=:time)
    # weighted seasons
    g_dsW = broadcast_dims.(*, weights, g_ds)
    weighted_g = sum.(g_dsW, dims = :time);
    weighted_g = dropdims.(weighted_g, dims=:time)
    # differences
    diff_g = map(.-, weighted_g, mean_g)
    seasons_g = lookup(mean_g, :time)
    return mean_g, weighted_g, diff_g, seasons_g
end
```


:::

::: info

In what follows, note how we are referencing the time dimension via `YAX.time`. This approach is used to avoid name clashes with `time` (`Time`) from **Base** (**Dates**). For convenience, we have defined the **Dimensions** `time` and `Time` in **YAXArrays.jl**, which are only accessible when explicitly called.

:::

Now, we continue with the `groupby` operations as usual

```julia
julia> g_ds = groupby(ds, YAX.time => seasons(; start=December))
```

```ansi
[90m┌ [39m[38;5;209m4-element [39mDimGroupByArray{YAXArray{Float64,3},1}[90m ┐[39m
[90m├──────────────────────────────────────────────────┴───────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Categorical{Symbol} [38;5;209m[:Dec_Jan_Feb, :Mar_Apr_May, :Jun_Jul_Aug, :Sep_Oct_Nov][39m [38;5;244mUnordered[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Symbol, Any} with 1 entry:
  :groupby => :time=>CyclicBins(month; cycle=12, step=3, start=12)…
[90m├────────────────────────────────────────────────────────────────── group dims ┤[39m
  [38;5;32m↓ [39m[38;5;32mx[39m, [38;5;81m→ [39m[38;5;81my[39m, [38;5;209m↗ [39m[38;5;209mtime[39m
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
 [38;5;209m:Dec_Jan_Feb[39m  [38;5;32m275[39m×[38;5;81m205[39m×[38;5;209m9[39m YAXArray
 [38;5;209m:Mar_Apr_May[39m  [38;5;32m275[39m×[38;5;81m205[39m×[38;5;209m9[39m YAXArray
 [38;5;209m:Jun_Jul_Aug[39m  [38;5;32m275[39m×[38;5;81m205[39m×[38;5;209m9[39m YAXArray
 [38;5;209m:Sep_Oct_Nov[39m  [38;5;32m275[39m×[38;5;81m205[39m×[38;5;209m9[39m YAXArray
```


And the mean per season is calculated as follows

```julia
julia> mean_g = mean.(g_ds, dims=:time)
```

```ansi
[90m┌ [39m[38;5;209m4-element [39mDimArray{YAXArray{Float64, 3, Array{Float64, 3}, Tuple{Dim{:x, DimensionalData.Dimensions.Lookups.Sampled{Int64, UnitRange{Int64}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Regular{Int64}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}, Dim{:y, DimensionalData.Dimensions.Lookups.Sampled{Int64, UnitRange{Int64}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Regular{Int64}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}, YAXArrays.time{DimensionalData.Dimensions.Lookups.Sampled{CFTime.DateTimeNoLeap, Vector{CFTime.DateTimeNoLeap}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Irregular{Tuple{Nothing, Nothing}}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}}, Dict{String, Any}}, 1}[90m ┐[39m
[90m├──────────────────────────────────────────────────────────────────────── dims ┤[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Categorical{Symbol} [38;5;209m[:Dec_Jan_Feb, :Mar_Apr_May, :Jun_Jul_Aug, :Sep_Oct_Nov][39m [38;5;244mUnordered[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Symbol, Any} with 1 entry:
  :groupby => :time=>CyclicBins(month; cycle=12, step=3, start=12)…
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
 [38;5;209m:Dec_Jan_Feb[39m  …  [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 11.1372 11.3835; NaN NaN … 11.3252 11.5843;;;]
 [38;5;209m:Mar_Apr_May[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 21.1363 21.018; NaN NaN … 21.4325 21.1762;;;]
 [38;5;209m:Jun_Jul_Aug[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 28.2818 27.9432; NaN NaN … 28.619 28.0537;;;]
 [38;5;209m:Sep_Oct_Nov[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 21.7119 21.7158; NaN NaN … 21.9682 21.9404;;;]
```


### dropdims {#dropdims}

Note that now the time dimension has length one, we can use `dropdims` to remove it

```julia
julia> mean_g = dropdims.(mean_g, dims=:time)
```

```ansi
[90m┌ [39m[38;5;209m4-element [39mDimArray{YAXArray{Float64, 2, Matrix{Float64}, Tuple{Dim{:x, DimensionalData.Dimensions.Lookups.Sampled{Int64, UnitRange{Int64}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Regular{Int64}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}, Dim{:y, DimensionalData.Dimensions.Lookups.Sampled{Int64, UnitRange{Int64}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Regular{Int64}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}}, Dict{String, Any}}, 1}[90m ┐[39m
[90m├──────────────────────────────────────────────────────────────────────── dims ┤[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Categorical{Symbol} [38;5;209m[:Dec_Jan_Feb, :Mar_Apr_May, :Jun_Jul_Aug, :Sep_Oct_Nov][39m [38;5;244mUnordered[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Symbol, Any} with 1 entry:
  :groupby => :time=>CyclicBins(month; cycle=12, step=3, start=12)…
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
 [38;5;209m:Dec_Jan_Feb[39m  …  [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 11.1372 11.3835; NaN NaN … 11.3252 11.5843]
 [38;5;209m:Mar_Apr_May[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 21.1363 21.018; NaN NaN … 21.4325 21.1762]
 [38;5;209m:Jun_Jul_Aug[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 28.2818 27.9432; NaN NaN … 28.619 28.0537]
 [38;5;209m:Sep_Oct_Nov[39m     [NaN NaN … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … 21.7119 21.7158; NaN NaN … 21.9682 21.9404]
```


### seasons {#seasons}

Due to the `groupby` function we will obtain new grouping names, in this case in the time dimension:

```julia
seasons_g = lookup(mean_g, :time)
```


```
Categorical{Symbol} Unordered
wrapping: 4-element Vector{Symbol}:
 :Dec_Jan_Feb
 :Mar_Apr_May
 :Jun_Jul_Aug
 :Sep_Oct_Nov
```


Next, we will weight this grouping by days/month in each group.

## GroupBy: weight {#GroupBy:-weight}

Create a `YAXArray` for the month length

```julia
tempo = dims(ds, :time)
month_length = YAXArray((tempo,), daysinmonth.(tempo))
```


```
┌ 36-element YAXArray{Int64, 1} ┐
├───────────────────────────────┴──────────────────────────────────────── dims ┐
  ↓ time Sampled{CFTime.DateTimeNoLeap} [CFTime.DateTimeNoLeap(1980-09-16T12:00:00), …, CFTime.DateTimeNoLeap(1983-08-17T00:00:00)] ForwardOrdered Irregular Points
├──────────────────────────────────────────────────────────────────── metadata ┤
  Dict{String, Any}()
├──────────────────────────────────────────────────────────── loaded in memory ┤
  data size: 288.0 bytes
└──────────────────────────────────────────────────────────────────────────────┘
```


Now group it by season 

```julia
julia> g_tempo = groupby(month_length, YAX.time => seasons(; start=December))
```

```ansi
[90m┌ [39m[38;5;209m4-element [39mDimGroupByArray{YAXArray{Int64,1},1}[90m ┐[39m
[90m├────────────────────────────────────────────────┴─────────────────────── dims ┐[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Categorical{Symbol} [38;5;209m[:Dec_Jan_Feb, :Mar_Apr_May, :Jun_Jul_Aug, :Sep_Oct_Nov][39m [38;5;244mUnordered[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Symbol, Any} with 1 entry:
  :groupby => :time=>CyclicBins(month; cycle=12, step=3, start=12)…
[90m├────────────────────────────────────────────────────────────────── group dims ┤[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
 [38;5;209m:Dec_Jan_Feb[39m  [38;5;209m9-element [39mYAXArray
 [38;5;209m:Mar_Apr_May[39m  [38;5;209m9-element [39mYAXArray
 [38;5;209m:Jun_Jul_Aug[39m  [38;5;209m9-element [39mYAXArray
 [38;5;209m:Sep_Oct_Nov[39m  [38;5;209m9-element [39mYAXArray
```


Get the number of days per season

```julia
julia> sum_days = sum.(g_tempo, dims=:time)
```

```ansi
[90m┌ [39m[38;5;209m4-element [39mDimArray{YAXArray{Int64, 1, DimensionalData.DimVector{Int64, Tuple{YAXArrays.time{DimensionalData.Dimensions.Lookups.Sampled{CFTime.DateTimeNoLeap, Vector{CFTime.DateTimeNoLeap}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Irregular{Tuple{Nothing, Nothing}}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}}, Tuple{}, Vector{Int64}, Symbol, DimensionalData.Dimensions.Lookups.NoMetadata}, Tuple{YAXArrays.time{DimensionalData.Dimensions.Lookups.Sampled{CFTime.DateTimeNoLeap, Vector{CFTime.DateTimeNoLeap}, DimensionalData.Dimensions.Lookups.ForwardOrdered, DimensionalData.Dimensions.Lookups.Irregular{Tuple{Nothing, Nothing}}, DimensionalData.Dimensions.Lookups.Points, DimensionalData.Dimensions.Lookups.NoMetadata}}}, Dict{String, Any}}, 1}[90m ┐[39m
[90m├──────────────────────────────────────────────────────────────────────── dims ┤[39m
  [38;5;209m↓ [39m[38;5;209mtime[39m Categorical{Symbol} [38;5;209m[:Dec_Jan_Feb, :Mar_Apr_May, :Jun_Jul_Aug, :Sep_Oct_Nov][39m [38;5;244mUnordered[39m
[90m├──────────────────────────────────────────────────────────────────── metadata ┤[39m
  Dict{Symbol, Any} with 1 entry:
  :groupby => :time=>CyclicBins(month; cycle=12, step=3, start=12)…
[90m└──────────────────────────────────────────────────────────────────────────────┘[39m
 [38;5;209m:Dec_Jan_Feb[39m  [270]
 [38;5;209m:Mar_Apr_May[39m  [276]
 [38;5;209m:Jun_Jul_Aug[39m  [276]
 [38;5;209m:Sep_Oct_Nov[39m  [273]
```


### weights {#weights}

Weight the seasonal groups by `sum_days`

::: danger WIP

DiskArrayEngine fails from here on...

:::

```julia compareXarray
weights = map(./, g_tempo, sum_days)
```


Verify that the sum per season is 1

```julia compareXarray
sum.(weights)
```


### weighted seasons {#weighted-seasons}

Now, let&#39;s weight the seasons

```julia compareXarray
g_dsW = broadcast_dims.(*, weights, g_ds)
```


apply a `sum` over the time dimension and drop it

```julia compareXarray
weighted_g = sum.(g_dsW, dims = :time);
weighted_g = dropdims.(weighted_g, dims=:time)
```


Calculate the differences

```julia compareXarray
diff_g = map(.-, weighted_g, mean_g)
```


All the previous steps are equivalent to calling the function defined at the top:

```julia
mean_g, weighted_g, diff_g, seasons_g = weighted_seasons(ds)
```


Once all calculations are done we can plot the results with `Makie.jl` as follows:

```julia compareXarray
using CairoMakie
# define plot arguments/attributes
colorrange = (-30,30)
colormap = Reverse(:Spectral)
highclip = :red
lowclip = :grey15
cb_label =  ds_o.properties["long_name"]
```


```julia compareXarray
with_theme(theme_ggplot2()) do
    hm_o, hm_d, hm_w = nothing, nothing, nothing
    # the figure
    fig = Figure(; size = (850,500))
    axs = [Axis(fig[i,j], aspect=DataAspect()) for i in 1:3, j in 1:4]
    for (j, s) in enumerate(seasons_g)
        hm_o = heatmap!(axs[1,j], mean_g[time=At(s)]; colorrange, lowclip, highclip, colormap)
        hm_w = heatmap!(axs[2,j], weighted_g[time=At(s)]; colorrange, lowclip, highclip, colormap)
        hm_d = heatmap!(axs[3,j], diff_g[time=At(s)]; colorrange=(-0.1,0.1), lowclip, highclip,
            colormap=:diverging_bwr_20_95_c54_n256)
    end
    Colorbar(fig[1:2,5], hm_o, label=cb_label)
    Colorbar(fig[3,5], hm_d, label="Tair")
    hidedecorations!.(axs, grid=false, ticks=false, label=false)
    # some labels
    [axs[1,j].title = string.(s) for (j,s) in enumerate(seasons_g)]
    Label(fig[0,1:5], "Seasonal Surface Air Temperature", fontsize=18, font=:bold)
    axs[1,1].ylabel = "Unweighted"
    axs[2,1].ylabel = "Weighted"
    axs[3,1].ylabel = "Difference"
    colgap!(fig.layout, 5)
    rowgap!(fig.layout, 5)
    fig
end
```


which shows a good agreement with the results first published by [Joe Hamman](https://github.com/jhamman/).
