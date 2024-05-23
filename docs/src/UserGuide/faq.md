# Frequently Asked Questions (FAQ)


The purpose of this section is to do a collection of small 
convinient pieces of code on how to do simple things.


## Extract the axes names from a Cube

````@example howdoi
using YAXArrays
using DimensionalData
````

````@ansi howdoi
c = YAXArray(rand(10, 10, 5))
caxes(c) # former way of doing it
````

::: warning

To get the axes of a YAXArray use the `dims` function instead of the `caxes` function

:::

````@ansi howdoi
dims(c)
````

::: info

Also, use __`DD.rebuild(ax, values)`__ instead of `axcopy(ax, values)` to copy an axes with the same name but different values.

:::

## Obtain values from axes and data from the cube

There are two options to collect values from axes. In this examples the axis ranges from 1 to 10.

These two examples bring the same result

````@example howdoi
collect(getAxis("Dim_1", c).val)
collect(c.axes[1].val)
````

to collect data from a cube works exactly the same as doing it from an array

````@ansi howdoi
c[:, :, 1]
````

## How do I concatenate cubes

It is possible to concatenate several cubes that shared the same dimensions using the [`concatenatecubes`]@ref function.

Let's create two dummy cubes
````@example howdoi
using YAXArrays
axlist = (
    Dim{:time}(range(1, 20, length=20)),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15))
    )

data1 = rand(20, 10, 15)
ds1 = YAXArray(axlist, data1)

data2 = rand(20, 10, 15)
ds2 = YAXArray(axlist, data2)
nothing # hide
````

Now we can concatenate `ds1` and `ds2`:

````@ansi howdoi
dsfinal = concatenatecubes([ds1, ds2], Dim{:Variables}(["var1", "var2"]))
````

## How do I subset a Cube?

Let's start by creating a dummy cube. Define the time span of the cube

````@example howdoi
using Dates
t = Date("2020-01-01"):Month(1):Date("2022-12-31")
````

create cube axes

````@example howdoi
axes = (Dim{:Lon}(1:10), Dim{:Lat}(1:10), Dim{:Time}(t))
````

assign values to a cube

````@ansi howdoi
c = YAXArray(axes, reshape(1:3600, (10, 10, 36)))
````

Now we subset the cube by any dimension.

Subset cube by years

````@ansi howdoi
ctime = c[Time=Between(Date(2021,1,1), Date(2021,12,31))]
````

Subset cube by a specific date and date range

````@ansi howdoi
ctime2 = c[Time=At(Date("2021-05-01"))]
ctime3 = c[Time=Date("2021-05-01") .. Date("2021-12-01")]
````

Subset cube by longitude and latitude

````@ansi howdoi
clonlat = c[Lon=1 .. 5, Lat=5 .. 10] # check even numbers range, it is ommiting them
````

##  How do I apply map algebra?

Our next step is map algebra computations. This can be done effectively using the 'map' function. For example:

Multiplying cubes with only spatio-temporal dimensions

````@ansi howdoi
map((x, y) -> x * y, ds1, ds2)
````

Cubes with more than 3 dimensions

````@ansi howdoi
map((x, y) -> x * y, dsfinal[Variables=At("var1")], dsfinal[Variables=At("var2")])
````

To add some complexity, we will multiply each value for π and then divided for the sum of each time step. We will use the `ds1` cube for this purpose.

````@ansi howdoi
mapslices(ds1, dims=("Lon", "Lat")) do xin
    (xin * π) ./ maximum(skipmissing(xin))
end
````

## How do I use the CubeTable function?

The function "CubeTable" creates an iterable table and the result is a DataCube. It is therefore very handy for grouping data and computing statistics by class. It uses `OnlineStats.jl` to calculate statistics, and weighted statistics can be calculated as well.

Here we will use the `ds1` Cube  defined previously and we create a mask for data classification.

Cube containing a mask with classes 1, 2 and 3.

````@ansi howdoi
classes = YAXArray((getAxis("lon", dsfinal), getAxis("lat", dsfinal)), rand(1:3, 10, 15))
````

````@example howdoi
using GLMakie
GLMakie.activate!()
# This is how our classification map looks like
fig, ax, obj = heatmap(classes;
    colormap=Makie.Categorical(cgrad([:grey15, :orangered, :snow3])))
cbar = Colorbar(fig[1,2], obj)
fig
````

Now we define the input cubes that will be considered for the iterable table

````@example howdoi
t = CubeTable(values=ds1, classes=classes)
````

````@example howdoi
using DataFrames
using OnlineStats
## visualization of the CubeTable
c_tbl = DataFrame(t[1])
first(c_tbl, 5)
````

In this line we calculate the `Mean` for each class

````@ansi howdoi
fitcube = cubefittable(t, Mean, :values, by=(:classes))
````

We can also use more than one criteria for grouping the values. In the next example, the mean is calculated for each class and timestep.

````@ansi howdoi
fitcube = cubefittable(t, Mean, :values, by=(:classes, :time))
````

## How do I assing variable names to `YAXArrays` in a `Dataset`

### One variable name

````@ansi howdoi
ds = YAXArrays.Dataset(; (:a => YAXArray(rand(10)),)...)
````

### Multiple variable names

````@example howdoi
keylist = (:a, :b, :c)
varlist = (YAXArray(rand(10)), YAXArray(rand(10,5)), YAXArray(rand(2,5)))
nothing # hide
````

````@ansi howdoi
ds = YAXArrays.Dataset(; (keylist .=> varlist)...)
````
