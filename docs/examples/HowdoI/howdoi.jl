# The purpose of this section is to do a collection of small 
# convinient pieces of code on how to do simple things.

# !!! question

# ## Extract the axes names from a Cube

using YAXArrays
c = YAXArray(rand(10,10,5))

caxes(c)

# !!! question

# ## Obtain values from axes and data from the cube

# There are two options to collect values from axes. In this examples the axis ranges from 1 to 10. Later we will see that axes can be `RangeAxis` such as latitude and longitude values, or `CategoricalAxis` which are strings such as variable names.

## this two examples bring the same result
collect(getAxis("Dim_1", c).values)
collect(c.axes[1].values)

## to collect data from a cube works exactly the same as doing it from an array
c[:,:,1]



# ## Concatenate cubes

# It is possible to concatenate several cubes that shared the same dimensions using the [`concatenatecubes`]@ref function.

# let's create two dummy cubes

using YAXArrays

axlist = [
    RangeAxis("time", range(1, 20, length=20)),
    RangeAxis("lon", range(1, 10, length=10)),
    RangeAxis("lat", range(1, 5, length=15))]

data1 = rand(20, 10, 15)
ds1 = YAXArray(axlist, data1)

data2 = rand(20, 10, 15)
ds2 = YAXArray(axlist, data2)

# Now we can concatenate ```ds1``` and ```ds2``` cubes:

dsfinal = concatenatecubes([ds1, ds2], 
    CategoricalAxis("Variables", ["var1", "var2"]))

dsfinal


# ##  Subsetting a Cube

# Let's start by creating a dummy cube

## define the time span of the cube
using Dates
t =  Date("2020-01-01"):Month(1):Date("2022-12-31")

## create cube axes
axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", t)]

## assign values to a cube
c = YAXArray(axes, reshape(1:3600, (10,10,36)))

# Now we subset the cube by any dimension

## subset cube by years
ctime = c[Time=2021:2022]

## subset cube by a specific date and date range
ctime2 = c[Time=Date(2021-01-05)]
ctime3 = c[Time=Date(2021-01-05)..Date(2021-01-12)] 

## subset cube by longitude and latitude
clonlat = c[Lon=1..5, Lat=5..10] # check even numbers range, it is ommiting them


# ##  Applying map algebra
# Our next step is map algebra computations. This can be done effectively using the 'map' function. For example:

## cubes with only spatio-temporal dimensions
map((x,y)->x*y, ds1, ds2)

## cubes with more than 3 dimensions
map((x,y)->x*y, dsfinal[Variables="Var1"], dsfinal[Variables="Var2"])

