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

ds_o = Cube("/Users/lalonso/Documents/YAXArrays.jl/docs/rasm.nc")
# The following should not be necessary in the next release, plus is unpractical to use for large data sets.
# Related to https://github.com/rafaqz/DimensionalData.jl/issues/642
axs = dims(ds_o) # get the dimensions
data = ds_o.data[:,:,:] # read the data
_FillValue = ds_o.properties["_FillValue"]
data = replace(data, _FillValue => NaN)
# create new YAXArray
ds = YAXArray(axs, data)

g_ds = groupby(ds, Ti => season(; start=December))
mean_g = mean.(g_ds, dims=:Ti)
mean_g = dropdims.(mean_g, dims=:Ti)

seasons = lookup(mean_g, :Ti)

## weighted seasons
# # Create a named array for the month length
tempo = dims(ds, :Ti)
month_length = YAXArray((tempo,), daysinmonth.(tempo))
    
g_tempo = groupby(month_length, Ti => season(; start=December))

sum_days = sum.(g_tempo, dims=:Ti)
# calculate weights
weights = map(./, g_tempo, sum_days)
# verify that the sum per season is 1.
sum.(weights)

g_dsW = broadcast_dims.(*, weights, g_ds) #
weighted_g = sum.(g_dsW, dims = :Ti)
# and lets drop the Time dimension
weighted_g = dropdims.(weighted_g, dims=:Ti)

ds_diff = map(.-, weighted_g, mean_g)

# define plot arguments/attributes
colorrange = (-30,30)
colormap = Reverse(:Spectral)
highclip = :red
lowclip = :grey15
cb_label =  ds_o.properties["long_name"]

# the plot
with_theme(theme_ggplot2()) do
    hm_o, hm_d, hm_w = nothing, nothing, nothing
    # the figure
    fig = Figure(; size = (850,500))
    axs = [Axis(fig[i,j], aspect=DataAspect()) for i in 1:3, j in 1:4]
    for (j, s) in enumerate(seasons)
        hm_o = heatmap!(axs[1,j], mean_g[Ti=At(s)]; colorrange, lowclip, highclip, colormap)
        hm_w = heatmap!(axs[2,j], weighted_g[Ti=At(s)]; colorrange, lowclip, highclip, colormap)
        hm_d = heatmap!(axs[3,j], ds_diff[Ti=At(s)]; colorrange=(-0.1,0.1), lowclip, highclip,
            colormap=:diverging_bwr_20_95_c54_n256)
    end
    Colorbar(fig[1:2,5], hm_o, label=cb_label)
    Colorbar(fig[3,5], hm_d, label="Tair")
    hidedecorations!.(axs, grid=false, ticks=false, label=false)
    # some labels
    [axs[1,j].title = string.(s) for (j,s) in enumerate(seasons)]
    Label(fig[0,1:5], "Seasonal Surface Air Temperature", fontsize=18, font=:bold)
    axs[1,1].ylabel = "Unweighted"
    axs[2,1].ylabel = "Weighted"
    axs[3,1].ylabel = "Difference"
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

