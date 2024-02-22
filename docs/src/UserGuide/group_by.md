# GroupBy
In the following example we will use the `groupby` function to calculate temporal and spatial averages.

````@example groupby
using YAXArrays, DimensionalData
using NetCDF
using Downloads
````

````@example compare_with_xarray
url_path = "https://github.com/pydata/xarray-data/blob/master/"
filename = Downloads.download(url_path, "rasm.nc")
ds = Cube(filename)
````

````@example compare_with_xarray
g = groupby(ds, Ti => season(; start=December))
m_g = mean.(g, dims=:Ti)
dropdims.(m_g, dims=:Ti)
````

# Create a named array for the month length

````@example compare_with_xarray
tempo = dims(ds, :Ti)
month_length = YAXArray((tempo,), daysinmonth.(tempo))
````

::: info

The same is possible with a pure DimArray, namely

````julia
month_length = DimArray(daysinmonth.(tempo), (tempo))
````

:::


g_tempo = groupby(month_length, Ti => season(; start=December))

sum_days = sum.(g_tempo, dims=:Ti)

```julia
month_length = YAXArray((tempo,), daysinmonth.(tempo))
g_tempo = groupby(month_length, Ti => season(; start=December))
sum_days = sum.(g_tempo, dims=:Ti)
weights = map(./, g_tempo, sum_days)
sum.(weights)

g_ds = groupby(ds, Ti => season(; start=December))

````
g_ds .* weights



