# The purpose of this section is to do a collection of small 
# convinient pieces of code on how to do simple things.

# !!! question

# ## extract the axes names from a Cube?

using YAXArrays
c = YAXArray(rand(10,10,5))

caxes(c)

# !!! question

# ## concatenate cubes?

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
t =  Date("2020-01-01"):Month(1):Date("2022-12-31")

## create cube axes
axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", t)]

## assign values to a cube
c = YAXArray(axes, reshape(1:3600, (10,10,36)))

# Now we subset the cube by any dimension

## subset cube by years
ctime = c[Time=2021:2022]

## subset cube by a specific date
ctime2 = c[Time=Date(2021-01-05)..Date()] # :Date(2021-01-12)

## subset cube by longitude and latitude
clonlat = c[Lon=1..5, Lat=(5,10)] # check even numbers range, it is ommiting them
