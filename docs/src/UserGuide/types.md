# Types

This section describes the data structures used to work with n-dimensional arrays in YAXArrays.

## YAXArray

An `Array` stores a sequence of ordered elements of the same type usually across multiple dimensions or axes.
For example, one can measure temperature across all time points of the time dimension or brightness values of a picture across X and Y dimensions.
A one dimensional array is called `Vector` and a two dimensional array is called a `Matrix`.
In many Machine Learning libraries, arrays are also called tensors.
Arrays are designed to store dense spatial-temporal data stored in a grid, whereas a collection of sparse points is usually stored in data frames or relational databases.

A `DimArray` as defined by (DimensionalData.jl)(https://rafaqz.github.io/DimensionalData.jl/dev/) adds names to the dimensions and their axes ticks for a given `Array`.
These names can be used to access the data, e.g., by date instead of just by integer position.

A `YAXArray` is a subtype of a `AbstractDimArray` and adds functions to load and process the named arrays.
For example, it can also handle very large arrays stored on disk that are too big to fit in memory.
In addition, it provides functions for parallel computation.

## Dataset

A `Dataset` is an ordered dictionary of `YAXArrays` that usually share dimensios.
For example, it can bundle arrays storing temperature and precipitation that are measured at the same time points and the same locations.
One also can store a picture in a Dataset with three arrays containing brightness values for red green and blue, respectiveley.
Internally, those arrays are still separated allowing to chose different element types for each array.
Analog to the (NetCDF Data Model)[https://docs.unidata.ucar.edu/netcdf-c/current/netcdf_data_model.html], a Dataset usually represents variables belonging to the same group.

## Cube 

A `Cube` is just a `YAXArray` in which arrays from a dataset are combined together by introducing a new dimension containing labels of which array the corresponding element came from.
Unlike a `Dataset`, all arrays must have the same element type to be converted into a cube.
This data structure is usefull when we want to use all variables at once.
For example, the arrays temperature and precipitation are combnined into a single cube.