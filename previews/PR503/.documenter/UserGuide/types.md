
# Types {#Types}

This section describes the data structures used to work with n-dimensional arrays in YAXArrays.

## YAXArray {#YAXArray}

An `Array` stores a sequence of ordered elements of the same type usually across multiple dimensions or axes. For example, one can measure temperature across all time points of the time dimension or brightness values of a picture across X and Y dimensions. A one dimensional array is called `Vector` and a two dimensional array is called a `Matrix`. In many Machine Learning libraries, arrays are also called tensors. Arrays are designed to store dense spatial-temporal data stored in a grid, whereas a collection of sparse points is usually stored in data frames or relational databases.

A `DimArray` as defined by [DimensionalData.jl](https://rafaqz.github.io/DimensionalData.jl/dev/dimarrays) adds names to the dimensions and their axes ticks for a given `Array`. These names can be used to access the data, e.g., by date instead of just by integer position.

A `YAXArray` is a subtype of a `AbstractDimArray` and adds functions to load and process the named arrays. For example, it can also handle very large arrays stored on disk that are too big to fit in memory. In addition, it provides functions for parallel computation.

## Dataset {#Dataset}

A `Dataset` is an ordered dictionary of `YAXArrays` that usually share dimensions. For example, it can bundle arrays storing temperature and precipitation that are measured at the same time points and the same locations. One also can store a picture in a Dataset with three arrays containing brightness values for red green and blue, respectively. Internally, those arrays are still separated allowing to chose different element types for each array. Analog to the (NetCDF Data Model)[https://docs.unidata.ucar.edu/netcdf-c/current/netcdf_data_model.html], a Dataset usually represents variables belonging to the same group.

## (Data) Cube {#Data-Cube}

A (Data) Cube is just a `YAXArray` in which arrays from a dataset are combined together by introducing a new dimension containing labels of which array the corresponding element came from. Unlike a `Dataset`, all arrays must have the same element type to be converted into a cube. This data structure is useful when we want to use all variables at once. For example, the arrays temperature and precipitation which are measured at the same locations and dates can be combined into a single cube. A more formal definition of Data Cubes are given in [Mahecha et al. 2020](https://doi.org/10.5194/esd-11-201-2020)

## Dimensions {#Dimensions}

A `Dimension` or axis as defined by [DimensionalData.jl](https://rafaqz.github.io/DimensionalData.jl/dev/dimensions) adds tick labels, e.g., to each row or column of an array. It&#39;s name is used to access particular subsets of that array.

### Lon, Lat, time {#Lon,-Lat,-time}

For convenience, several `Dimensions` have been defined in `YAXArrays.jl`, but only a few have been exported. The remaining dimensions can be used by calling them explicitly. See the next table for an overview

| Dimension   | exported | usage: `using YAXArrays: YAXArrays as YAX` |
|:----------- |:-------- | ------------------------------------------:|
| `lon`       | ✔        |                         `lon` or `YAX.lon` |
| `Lon`       | ✔        |                         `Lon` or `YAX.Lon` |
| `longitude` | ✔        |             `longitude` or `YAX.longitude` |
| `Longitude` | ✔        |             `Longitude` or `YAX.Longitude` |
| `lat`       | ✔        |                         `lat` or `YAX.lat` |
| `Lat`       | ✔        |                         `Lat` or `YAX.Lat` |
| `latitude`  | ✔        |               `latitude` or `YAX.latitude` |
| `Latitude`  | ✔        |               `Latitude` or `YAX.Latitude` |
| `time`      | ✘        |                                 `YAX.time` |
| `Time`      | ✘        |                                 `YAX.Time` |
| `rlat`      | ✘        |                                 `YAX.rlat` |
| `rlon`      | ✘        |                                 `YAX.rlon` |
| `lat_c`     | ✘        |                                `YAX.lat_c` |
| `lon_c`     | ✘        |                                `YAX.lon_c` |
| `height`    | ✘        |                               `YAX.height` |
| `depth`     | ✘        |                                `YAX.depth` |
| `Variables` | ✔        |             `Variables` or `YAX.Variables` |


::: info

If the dimension you are looking for is not in that table, you can define your own by doing

```julia
using DimensionalData: @dim, XDim # If you want it to be a subtype of XDim
@dim newDim XDim "Your newDim label"
```


Sometimes, when you want to operate on a specific dimension in your dataset (for example, a dimension named `date`), then doing

```julia
groupby(ds, Dim{:date} => seasons())
```


should do the job.

:::
