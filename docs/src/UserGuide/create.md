# Create YAXArrays and Datasets

This section describes how to create arrays and datasets by filling values directly.

## Create a YAXArray

We can create a new YAXArray by filling the values directly:

````@example create
using YAXArrays: YAXArrays as YAX, YAXArrays
a1 = YAXArray(rand(10, 20, 5))
````

The dimensions have only generic names, e.g. `Dim_1` and only integer values.
We can also specify the dimensions with custom names enabling easier access:

````@example create
using Dates

axlist = (
    YAX.time(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15)),
)
data2 = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a2 = YAXArray(axlist, data2, properties)
````

````@example create
a2.properties
````

````@example create
a2.axes
````

## Create a Dataset

````@example create
data3 = rand(30, 10, 15)
a3 = YAXArray(axlist, data3, properties)

arrays = Dict(:a2 => a2, :a3 => a3)
ds = Dataset(; properties, arrays...)
````