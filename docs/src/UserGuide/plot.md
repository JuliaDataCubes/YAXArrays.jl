# Plot YAXArrays

This section describes how to visualize YAXArrays.
See also the [Plotting maps tutorial](/tutorials/plottingmaps.html) to plot geospatial data.
All [plotting capabilities](https://rafaqz.github.io/DimisensionalData.jl/dev/plots) of `AbstractDimArray` apply to a `YAXArrays` as well, because every `YAXArray` is also an `AbstractDimArray`.

## Plot a YAXArrray

Create a simple YAXArray:

```@example plot
using CairoMakie
using YAXArrays
using DimensionalData

data = collect(reshape(1:20, 4, 5))
axlist = (X(1:4), Y(1:5))
a = YAXArray(axlist, data)
```

Plot the entire array:

```@example plot
plot(a)
```

This will plot a heatmap, because the array is a matrix.

Plot the first column:

```@example plot
plot(a[Y=1])
```

This results in a scatter plot, because the subarray is a vector.

## Plot a YAXArrray with CF conventions

[Climate and Forecast Metadata Conventions](https://cfconventions.org/) are used to generate appropriate labels for the plot whenever possible.
This requires the YAXArray to have metadata properties like `standard_name` and `units`.

Get a `Dataset` with CF meta data:

```@example plot
using NetCDF
using Downloads: download

path = download("https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc", "example.nc")
ds = open_dataset(path)
```

Plot the first time step of the sea surface temperature with CF metadata:

```@example plot
plot(ds.tos[time=1])
```

Time in [Climate and Forecasting (CF) conventions](https://cfconventions.org/Data/cf-conventions/cf-conventions-1.12/cf-conventions.html#time-coordinate-units) requires conversion before plotting, e.g., to plot the sea surface temperature over time at a given location (e.g. the null island):

```@example plot
a = ds.tos[lon = Near(0), lat = Near(0)]
times = Ti(map(x -> DateTime(string(x)), a.time.val))
a = YAXArray((times,), collect(a.data), a.properties)
```

```@example plot
plot(a)
```

Or as as an explicit line plot:

```@example plot
lines(a)
```
