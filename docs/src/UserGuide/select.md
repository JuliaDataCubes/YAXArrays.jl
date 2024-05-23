# Select YAXArrays and Datasets

The dimensions or axes of an `YAXArray` are named making it easier to subset or query certain ranges of an array.
Let's open an example `Dataset` used to select certain elements:

````@example subset
using YAXArrays
using NetCDF
using Downloads: download

path = download("https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc", "example.nc")
ds = open_dataset(path)
````

## Select a YAXArray

Get the sea surface temperature of the `Dataset`:

````@example subset
tos = ds.tos
````

which is the same as:

````@example subset
tos = ds.cubes[:tos]
````

## Select elements

Using positional integer indexing:

````@example subset
tos[lon = 1, lat = 1]
````

Same but using named indexing:

````@example subset
tos[lon = At(1), lat = At(-79.5)]
````

Using special types:

````@example subset
using CFTime
time1 = DateTime360Day(2001,01,16)
tos[time = At(time1)]
````

## Select ranges

Here we subset an interval of a dimension using positional integer indexing.

````@example subset
tos[lon = 1:10, lat = 1:10]
````

Same but using named indexing:

````@example subset
tos[lon = At(1.0:2:19), lat = At(-79.5:1:-70.5)]
````

Read more about the `At` selector in the package `DimensionalData`.
Get values within a tolerances:

````@example subset
tos[lon = At(1:10; atol = 1)]
````

## Closed and open intervals

Although a `Between(a,b)` function is available in `DimensionalData`, is recommended to use instead the `a .. b` notation:

````@example subset
tos[lon = 90 .. 180]
````

This describes a closed interval in which all points were included. 
More selectors from DimensionalData are available, such as `Touches`, `Near`, `Where` and `Contains`.


````@example subset
using IntervalSets
````

````@ansi subset
tos[lon = OpenInterval(90, 180)]
````

````@ansi subset
tos[lon = ClosedInterval(90, 180)]
````
````@ansi subset
tos[lon =Interval{:open,:closed}(90,180)]
````
````@ansi subset
tos[lon =Interval{:closed,:open}(90,180)]
````

See tutorials for use cases.

## Get a dimension

Get values, .e.g., axis tick labels, of a dimension that can be used for subseting:

````@example subset
collect(tos.lat)
````

These values are defined as lookups in the package `DimensionalData`:

````@example subset
lookup(tos, :lon)
````

which is equivalent to:

````@example subset
tos.lon.val
````