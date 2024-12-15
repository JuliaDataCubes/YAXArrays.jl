# Group YAXArrays and Datasets

The following examples will use the `groupby` function to calculate temporal and spatial averages.

````@example compareXarray
using YAXArrays, DimensionalData
using YAXArrays: YAXArrays as YAX
using NetCDF
using Downloads
using Dates
using Statistics
````

### Seasonal Averages from Time Series of Monthly Means

The following reproduces the example in [xarray](https://docs.xarray.dev/en/stable/examples/monthly-means.html) by [Joe Hamman](https://github.com/jhamman/).

Where the goal is to calculate the seasonal average. And in order to do this properly, is necessary to calculate the weighted average considering that each month has a different number of days.

### Download the data

````@example compareXarray
url_path = "https://github.com/pydata/xarray-data/raw/master/rasm.nc"
filename = Downloads.download(url_path, "rasm.nc")
ds_o = Cube(filename)
````

::: warning

The following rebuild should not be necessary in the future, plus is unpractical to use for large data sets. Out of memory groupby currently is work in progress.
Related to https://github.com/rafaqz/DimensionalData.jl/issues/642

:::

````@example compareXarray
_FillValue = ds_o.properties["_FillValue"]
ds = replace(ds_o[:,:,:], _FillValue => NaN) # load into memory and replace _FillValue by NaN
````

## GroupBy: seasons

::: details function weighted_seasons(ds) ... end

````julia
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
````
:::

Now, we continue with the `groupby` operations as usual

````@ansi compareXarray
g_ds = groupby(ds, YAX.time => seasons(; start=December))
````

> [!IMPORTANT]
> Note how we are referencing the `time` dimension via `YAX.time`. This approach is used to avoid name clashes with `time` (`Time`) from `Base` (`Dates`). For convenience, we have defined the `Dimensions` `time` and `Time` in `YAXArrays.jl`, which are only accessible when explicitly called.

And the mean per season is calculated as follows

````@ansi compareXarray
mean_g = mean.(g_ds, dims=:time)
````

### dropdims

Note that now the time dimension has length one, we can use `dropdims` to remove it

````@ansi compareXarray
mean_g = dropdims.(mean_g, dims=:time)
````

### seasons

Due to the `groupby` function we will obtain new grouping names, in this case in the time dimension:

````@example compareXarray
seasons_g = lookup(mean_g, :time)
````

Next, we will weight this grouping by days/month in each group.

## GroupBy: weight

Create a `YAXArray` for the month length

````@example compareXarray
tempo = dims(ds, :time)
month_length = YAXArray((tempo,), daysinmonth.(tempo))
````

Now group it by season 

````@ansi compareXarray  
g_tempo = groupby(month_length, YAX.time => seasons(; start=December))
````

Get the number of days per season

````@ansi compareXarray  
sum_days = sum.(g_tempo, dims=:time)
````

### weights

Weight the seasonal groups by `sum_days`

````@ansi compareXarray
weights = map(./, g_tempo, sum_days)
````

Verify that the sum per season is 1

````@ansi compareXarray
sum.(weights)
````
### weighted seasons

Now, let's weight the seasons

````@ansi compareXarray
g_dsW = broadcast_dims.(*, weights, g_ds)
````

apply a `sum` over the time dimension and drop it

````@ansi compareXarray
weighted_g = sum.(g_dsW, dims = :time);
weighted_g = dropdims.(weighted_g, dims=:time)
````

Calculate the differences

````@ansi compareXarray
diff_g = map(.-, weighted_g, mean_g)
````

All the previous steps are equivalent to calling the function defined at the top:

````julia
mean_g, weighted_g, diff_g, seasons_g = weighted_seasons(ds)
````

Once all calculations are done we can plot the results with `Makie.jl` as follows:

````@example compareXarray
using CairoMakie
# define plot arguments/attributes
colorrange = (-30,30)
colormap = Reverse(:Spectral)
highclip = :red
lowclip = :grey15
cb_label =  ds_o.properties["long_name"]
````

````@example compareXarray
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
````

which shows a good agreement with the results first published by [Joe Hamman](https://github.com/jhamman/).