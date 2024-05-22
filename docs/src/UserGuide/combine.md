# Combine YAXArrays

Data is often scattered across multiple files and corresponding arrays, e.g. one file per time step.
This section describes methods on how to combine them into a single YAXArray.

## Concatenate YAXArrays along an existing dimension

Here we use `cat` to combine two arrays consisting of data from the first and the second half of a year into one single array containing the whole year.
We glue the arrays along the first dimension using `dims = 1`:
The resulting array `whole_year` still has one dimension, i.e. time, but with 12 instead of 6 elements.

````@example cat
using YAXArrays

first_half = YAXArray((Dim{:time}(1:6),), rand(6))
second_half = YAXArray((Dim{:time}(7:12),), rand(6))
whole_year = cat(first_half, second_half, dims = 1)
````

## Combine YAXArrays along a new dimension

Here we use `concatenatecubes` to combine two arrays of different variables that share the same time dimension.
The resulting array `combined` has an additional dimension `variable` indicating from which array the element values originates.

````@example concatenatecubes
using YAXArrays

temperature = YAXArray((Dim{:time}(1:6),), rand(6))
precipitation = YAXArray((Dim{:time}(1:6),), rand(6))
cubes = [temperature,precipitation]
var_axis = Dim{:variable}(["temp", "prep"])
combined = concatenatecubes(cubes, var_axis)
````