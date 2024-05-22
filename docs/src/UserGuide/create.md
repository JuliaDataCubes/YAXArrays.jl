# Create YAXArrays and Datasets

## Create a YAXArray

We can create a new YAXArray by filling the values directly:

````@example create
using YAXArrays
a1 = YAXArray(rand(10, 20, 5))
````

We can also specify the dimensions with custom names enabling easier access:

````@example create
using Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
)
data2 = rand(30, 10, 15)
properties = Dict(:origin => "user guide")
a2 = YAXArray(axlist, data2, properties)
````

## Create a Dataset

````@example create
data3 = rand(30, 10, 15)
a3 = YAXArray(axlist, data3, properties)

arrays = Dict(:a2 => a2, :a3 => a3)
ds = Dataset(; properties, arrays...)
````