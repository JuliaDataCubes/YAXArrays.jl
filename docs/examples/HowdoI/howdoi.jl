# The purpose of this section is to do a collection of small 
# convinient pieces of code on how to do simple things.

# !!! question

# ## Extract the axes names from a Cube

using YAXArrays
using DimensionalData
c = YAXArray(rand(10, 10, 5))

caxes(c)

# !!! question

# ## Obtain values from axes and data from the cube

# There are two options to collect values from axes. In this examples the axis ranges from 1 to 10. Later we will see that axes can be `RangeAxis` such as latitude and longitude values, or `CategoricalAxis` which are strings such as variable names.

## this two examples bring the same result
collect(getAxis("Dim_1", c).values)
collect(c.axes[1].values)

## to collect data from a cube works exactly the same as doing it from an array
c[:, :, 1]



# ## Concatenate cubes

# It is possible to concatenate several cubes that shared the same dimensions using the [`concatenatecubes`]@ref function.

# let's create two dummy cubes

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

# Now we can concatenate ```ds1``` and ```ds2``` cubes:

dsfinal = concatenatecubes([ds1, ds2], Dim{:Variables}(["var1", "var2"]))

dsfinal


# ## How do I subset a Cube?

# Let's start by creating a dummy cube

## define the time span of the cube
using Dates
t = Date("2020-01-01"):Month(1):Date("2022-12-31")

## create cube axes
axes = (Dim{:Lon}(1:10), Dim{:Lat}(1:10), Dim{:Time}(t))

## assign values to a cube
c = YAXArray(axes, reshape(1:3600, (10, 10, 36)))

# Now we subset the cube by any dimension

## subset cube by years
ctime = c[Time=Between(Date(2021,1,1), Date(2021,12,31))]

## subset cube by a specific date and date range
ctime2 = c[Time=At(Date("2021-05-01"))]
ctime3 = c[Time=Date("2021-05-01") .. Date("2021-12-01")]

## subset cube by longitude and latitude
clonlat = c[Lon=1 .. 5, Lat=5 .. 10] # check even numbers range, it is ommiting them


# ##  How do I apply map algebra?
# Our next step is map algebra computations. This can be done effectively using the 'map' function. For example:

## multiplying cubes with only spatio-temporal dimensions
map((x, y) -> x * y, ds1, ds2)

## cubes with more than 3 dimensions
map((x, y) -> x * y, dsfinal[Variables=At("var1")], dsfinal[Variables=At("var2")])

# To add some complexity, we will multiply each value for π and then divided for the sum of each time step. We will use the `ds1` cube for this purpose.
mapslices(ds1, dims=("Lon", "Lat")) do xin
    (xin * π) ./ maximum(skipmissing(xin))
end

# ## How do I use the CubeTable function?
# The function "CubeTable" creates an iterable table and the result is a DataCube. It is therefore very handy for grouping data and computing statistics by class. It uses `OnlineStats.jl` to calculate statistics, and weighted statistics can be calculated as well.

# Here we will use the `ds1` Cube  defined previously and we create a mask for data classification.

## cube containing a mask with classes 1, 2 and 3
classes = YAXArray((getAxis("lon", dsfinal), getAxis("lat", dsfinal)), rand(1:3, 10, 15))

using CairoMakie
CairoMakie.activate!()
# This is how our classification map looks like
heatmap(classes[:, :])

# Now we define the input cubes that will be considered for the iterable table
t = CubeTable(values=ds1, classes=classes)

using DataFrames
using OnlineStats
## visualiztion of the CubeTable
DataFrame(t[1])

# In this line we calculate the `Mean` for each class
fitcube = cubefittable(t, Mean, :values, by=(:classes))

# We can also use more than one criteria for grouping the values. In the next example, the mean is calculated for each class and timestep.
fitcube = cubefittable(t, Mean, :values, by=(:classes, :time))
