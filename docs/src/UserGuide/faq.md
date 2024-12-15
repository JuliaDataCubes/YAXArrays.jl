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

Also, use __`DD.rebuild(c, values)`__  to copy axes from `c` and build a new cube but with different values.

:::

### rebuild
As an example let's consider the following

````@example howdoi
using YAXArrays
using DimensionalData

c = YAXArray(ones(Int, 10,10))
````

then creating a new `c` with the same structure (axes) but different values is done by

````@ansi howdoi
new_c = rebuild(c, rand(10,10))
````

note that the type is now `Float64`. Or, we could create a new structure but using the dimensions from `yax` explicitly

````@ansi howdoi
c_c = YAXArray(dims(c), rand(10,10))
````

which achieves the same goal as `rebuild`.

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
using YAXArrays: YAXArrays as YAX

axlist = (
    YAX.time(range(1, 20, length=20)),
    lon(range(1, 10, length=10)),
    lat(range(1, 5, length=15))
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

## How do I subset a YAXArray ( Cube ) or Dataset?

These are the three main datatypes provided by the YAXArrays libray. You can find a description of them [here](https://juliadatacubes.github.io/YAXArrays.jl/dev/UserGuide/types). A Cube is no more than a YAXArray, so, we will not explicitly tell about a Cube.

### Subsetting a YAXArray

Let's start by creating a dummy YAXArray.

Firstly, load the required libraries
```@example howdoi
using YAXArrays
using Dates # To generate the dates of the time axis
using DimensionalData # To use the "Between" option for selecting data, however the intervals notation should be used instead, i.e. `a .. b`.
```

Define the time span of the YAXArray

```@example howdoi
t = Date("2020-01-01"):Month(1):Date("2022-12-31")
```

create YAXArray axes

```@example howdoi
axes = (Lon(1:10), Lat(1:10), YAX.Time(t))
```

create the YAXArray
```@example howdoi
y = YAXArray(axes, reshape(1:3600, (10, 10, 36)))
```
Now we subset the YAXArray by any dimension.

Subset YAXArray by years

```@example howdoi
ytime = y[Time=Between(Date(2021,1,1), Date(2021,12,31))]
```

Subset YAXArray by a specific date
```@example howdoi
ytime2 = y[Time=At(Date("2021-05-01"))]
```
Subset YAXArray by a date range
```@example howdoi
ytime3 = y[Time=Date("2021-05-01") .. Date("2021-12-01")]
```

Subset YAXArray by longitude and latitude

```@example howdoi
ylonlat = y[Lon=1 .. 5, Lat=5 .. 10]
```

### Subsetting a Dataset

In a dataset, we can have several variables (YAXArrays) that share some or all of their dimensions.

#### Subsetting a Dataset whose variables share all their dimensions

This works for YAXArrays. Let's make an example.

```@example howdoi
using YAXArrays
using Dates # To generate the dates of the time axis
using DimensionalData # To use the "Between" option for selecting data

t = Date("2020-01-01"):Month(1):Date("2022-12-31")
axes = (Lon(1:10), Lat(1:10), YAX.Time(t))

var1 = YAXArray(axes, reshape(1:3600, (10, 10, 36)))
var2 = YAXArray(axes, reshape((1:3600)*5, (10, 10, 36)))

ds = Dataset(; var1=var1, var2=var2)
```
```@example howdoi
ds_lonlat = ds[Lon=1 .. 5, Lat=5 .. 10]
```
#### Subsetting a Dataset whose variables share some but not all of their dimensions

In this case, if we subset by the common dimension/s, this works the same as for YAXArrays, Cubes, and datasets that share all their dimensions.

But we can also subset a variable by the values of another variable with which it shares some dimensions.
!!! warning
     If your data is not loaded into memory, the selection will be too slow. So, you have load into memory, at least, the variable with which you make the selection.

Let's make an example.
```@example howdoi
using YAXArrays
using Dates # To generate the dates of the time axis
using DimensionalData # To use the "Between" selector for selecting data

t = Date("2020-01-01"):Month(1):Date("2022-12-31")
common_axis = Dim{:points}(1:100)
time_axis =   YAX.Time(t)

# Note that longitudes and latitudes are not dimensions, but YAXArrays
longitudes = YAXArray((common_axis,), rand(1:369, 100)) # 100 random values taken from 1 to 359
latitudes  = YAXArray((common_axis,), rand(0:90, 100))  # 100 random values taken from 0 to 90
temperature = YAXArray((common_axis, time_axis), rand(-40:40, (100, 36)))

ds = Dataset(; longitudes=longitudes, latitudes=latitudes, temperature=temperature)
```
Select all points between 20ºN and 85ºN, and 0ºE to 180ºE
```@example howdoi
ds_subset = ds[points = Where(p-> ds["latitudes"][p]  >= 20 && ds["latitudes"][p]  <= 80 &&
                             ds["longitudes"][p] >= 0  && ds["longitudes"][p] <= 180
                             ) # Where
              ] # ds
```
If your dataset has been read from a file with `Cube` it is not loaded into memory, and you have to load the `latitudes` and `longitudes` YAXArrays into memory:
```@example howdoi
latitudes_yasxa  = readcubedata(ds["latitudes"])
longitudes_yasxa = readcubedata(ds["longitudes"])
ds_subset = ds[points = Where(p-> latitudes_yasxa[p]  >= 20 && latitudes_yasxa[p]  <= 80 &&
                             longitudes_yasxa[p] >= 0  && longitudes_yasxa[p] <= 180
                             ) # Where
              ] # ds
```

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

## How do I assign variable names to `YAXArrays` in a `Dataset`

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

::: warning

You will not be able to save this dataset, first you will need to rename those `dimensions` with the `same name` but different values.

:::

## Ho do I construct a `Dataset` from a TimeArray

In this section we will use `MarketData.jl` and `TimeSeries.jl` to simulate some stocks.

````@example howdoi
using YAXArrays
using YAXArrays: YAXArrays as YAX
using DimensionalData
using MarketData, TimeSeries

stocks = Dict(:Stock1 => random_ohlcv(), :Stock2 => random_ohlcv(), :Stock3 => random_ohlcv())
d_keys = keys(stocks)
````

currently there is not direct support to obtain `dims` from a `TimeArray`, but we can code a function for it

````@example howdoi
getTArrayAxes(ta::TimeArray) = (YAX.time(timestamp(ta)), Dim{:variable}(colnames(ta)), );
nothing # hide
````
then, we create the `YAXArrays` as

````@example howdoi
yax_list = [YAXArray(getTArrayAxes(stocks[k]), values(stocks[k])) for k in d_keys];
nothing # hide
````

and a `Dataset` with all `stocks` names

````@ansi howdoi
ds = Dataset(; (d_keys .=> yax_list)...)
````

and, it looks like there some small differences in the axes, they are being printed independently although they should be the same. Well, they are at least at the `==` level but not at `===`. We could use the axes from one `YAXArray` as reference and `rebuild` all the others

````@example howdoi
yax_list = [rebuild(yax_list[1], values(stocks[k])) for k in d_keys];
nothing # hide
````

and voilà

````@ansi howdoi
ds = Dataset(; (d_keys .=> yax_list)...)
````

now they are printed together, showing that is exactly the same axis structure for all variables.

## Create a  `YAXArray` with unions containing `Strings`

````@example howdoi
test_x = stack(Vector{Union{Int,String}}[[1, "Test"], [2, "Test2"]])
yax_string = YAXArray(test_x)
````

or simply with an `Any` type

````@example howdoi
test_bool = ["Test1" 1 false; 2 "Test2" true; 1 2f0 1f2]
yax_bool = YAXArray(test_bool)
````

::: warning

Note that although their creation is allowed, it is not possible to save these types into Zarr or NetCDF.

:::