# Convert YAXArrays

This section describes how to convert variables from types of other Julia packages into YAXArrays and vice versa.


::: warning

YAXArrays is designed to work with large datasets that are way larger than the memory.
However, most types are designed to work in memory.
Those conversions are only possible if the entire dataset fits into memory.
In addition, metadata might be lost during conversion.

:::


## Convert `Base.Array`

Convert `Base.Array` to `YAXArray`:

````@example convert
using YAXArrays

m = rand(5,10)
a = YAXArray(m)
````

Convert `YAXArray` to `Base.Array`:

````@example convert
m2 = collect(a.data)
````

## Convert `Raster`

A `Raster` as defined in [Rasters.jl](https://rafaqz.github.io/Rasters.jl/stable/) has a same supertype of a `YAXArray`, i.e. `AbstractDimArray`, allowing easy conversion between those types:

````@example convert
using Rasters

lon, lat = X(25:1:30), Y(25:1:30)
time = Ti(2000:2024)
ras = Raster(rand(lon, lat, time))
a = YAXArray(dims(ras), ras.data)
````

````@example convert
ras2 = Raster(a)
````