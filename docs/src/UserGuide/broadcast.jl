# GroupBy
using YAXArrays, DimensionalData
using NetCDF
using Downloads
using Dates
using Statistics
using GLMakie
# url_path = "https://github.com/pydata/xarray-data/blob/master/"
# filename = Downloads.download(url_path, "rasm.nc")
#ds = Cube(filename)

ds = Cube("/Users/lalonso/Documents/YAXArrays.jl/docs/rasm.nc")

g = groupby(ds, Ti => season(; start=December))
mean_g = mean.(g, dims=:Ti)
mean_g = dropdims.(mean_g, dims=:Ti)
#mean_g[Ti=At(:Dec_Jan_Feb)]
seasons = lookup(mean_g, :Ti)

# plot arguments/attributes
_FillValue = ds.properties["_FillValue"]
colorrange = (-30,30)
colormap = Reverse(:Spectral)
highclip = :red
lowclip = :grey15
cb_label =  ds.properties["long_name"]

# the plot
with_theme(theme_ggplot2()) do
    hm_obj = nothing
    hm_diff=nothing
    fig = Figure(; size = (850,500))
    axs = [Axis(fig[i,j], aspect=DataAspect()) for i in 1:3, j in 1:4]
    for j in 1:4
        hm_obj = heatmap!(axs[1,j], replace(mean_g[j], _FillValue => NaN);
            colorrange, colormap, lowclip, highclip)
        heatmap!(axs[2,j], replace(mean_g[j], _FillValue => NaN);
            colorrange, colormap, lowclip, highclip)
        hm_diff = heatmap!(axs[3,j], replace(mean_g[j], _FillValue => NaN);
            colorrange=(-0.1,0.1),
            colormap=:diverging_bwr_20_95_c54_n256,
            lowclip, highclip)
    end
    Colorbar(fig[1:2,5], hm, label=cb_label)
    Colorbar(fig[3,5], hm_diff, label="Tair")
    hidedecorations!.(axs, grid=false, ticks=false, label=false)
    # some labels
    [axs[1,j].title = string.(s) for (j,s) in enumerate(seasons)]
    Label(fig[0,1:5], "Seasonal Surface Air Temperature", fontsize=18, font=:bold)
    axs[1,1].ylabel = "unweighted"
    axs[2,1].ylabel = "weighted"
    axs[3,1].ylabel = "difference"
    colgap!(fig.layout, 5)
    rowgap!(fig.layout, 5)
    fig
end

ds = Cube("/Users/lalonso/Documents/YAXArrays.jl/docs/air_temperature.nc")

# groupby(ds, Ti => hours(12; start=6, labels=x -> 6 in x ? :day : :night))

groupby(ds, Ti => dayofyear)

yearday(x) = year(x), dayofyear(x)
yearhour(x) = year(x), hour(x)

groupby(ds, Ti=>Bins(yearhour, 12)) # this does a daily mean aggregation

# # Create a named array for the month length

tempo = dims(ds, :Ti)
month_length = YAXArray((tempo,), daysinmonth.(tempo))
    

g_tempo = groupby(month_length, Ti => season(; start=December))

sum_days = sum.(g_tempo, dims=:Ti)

month_length = YAXArray((tempo,), daysinmonth.(tempo))
g_tempo = groupby(month_length, Ti => season(; start=December))
sum_days = sum.(g_tempo, dims=:Ti)
weights = map(./, g_tempo, sum_days)
sum.(weights)

g_ds = groupby(ds, Ti => season(; start=December))

# g_ds .* weights
g_ds_w = broadcast_dims.(*, DimArray.(weights), DimArray.(g_ds))


using YAXArrays, DimensionalData, NetCDF, Statistics
using Dates
using YAXArrayBase
# this fails
yearhour(x) = year(x), hour(x)
yearday(x) = year(x), dayofyear(x)

ds_o = Cube("air_temperature.nc")
ds = readcubedata(ds_o)
ds_dim = yaxconvert(DimArray, ds)

groupby(ds_dim, Dim{:Ti} => Bins(yearhour, 12)) # this does a daily mean aggregation

groupby(ds_dim, Dim{:Ti} => Bins(yearday, 1:365)) # this does a daily mean aggregation

groupby(ds_dim, Dim{:Ti} => Bins(dayofyear, 1:365)) # this does a daily mean aggregation

groupby(ds_dim, Dim{:Ti}=>Bins(dayofyear, map(x -> x:x+7, 1:8:370)))

