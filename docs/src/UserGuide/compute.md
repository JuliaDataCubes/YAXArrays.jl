# Compute YAXArrays

This section describes how to create new YAXArrays by performing operations on them.

- Use [arithmetics](#Arithmetics) to add or multiply numbers to each element of an array
- Use [map](#map) to apply a more complex functions to every element of an array
- Use [mapslices](#mapslices) to reduce a dimension, e.g. to get the mean over all time steps
- Use [mapCube](#mapCube) to apply complex functions on an array that may change any dimensions


Let's start by creating an example dataset:

````@example compute
using YAXArrays
using Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
)
data = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a = YAXArray(axlist, data2, properties)
````

## Modify elements of a YAXArray

````@example compute
a[1,2,3]
````

````@example compute
a[1,2,3] = 42
````

````@example compute
a[1,2,3]
````

::: warning

Some arrays, e.g. those saved in a cloud object storage are immutable making any modification of the data impossible.

:::


## Arithmetics

Add a value to all elements of an array and save it as a new array:

````@example compute
a2 = a .+ 5
````

````@example compute
a2[1,2,3] == a[1,2,3] + 5
````

## map

Apply a function on every element of an array individually:

````@example compute
offset = 5
map(a) do x
    (x + offset) / 2 * 3
end
````

This keeps all dimensions unchanged.
Note, that here we can not access neighboring elements.
In this case, we can use `mapslices` or `mapCube` instead.
Each element of the array is processed individually.

The code runs very fast, because `map` applies the function lazily.
Actual computation will be performed only on demand, e.g. when elements were explicitly requested or further computations were performed.


## mapslices

Reduce the time dimension by calculating the average value of all time points:

````@example compute
import Statistics: mean
mapslices(mean, a, dims="Time")
````
There is no time dimension left, because there is only one value left after averaging all time steps.
We can also calculate spatial means resulting in one value per time step:

````@example compute
import Statistics: mean
mapslices(mean, a, dims=("lat", "lon"))
````

## mapCube



## Distributed Computation

parallel