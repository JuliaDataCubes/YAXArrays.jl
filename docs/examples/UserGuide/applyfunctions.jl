# How to apply functions on YAXArrays

# To apply user defined functions on a YAXArray data type we can use the [`map`](@ref) function, 
# [`mapslices`](@ref) function or the [`mapCube`](@ref) function.  Which of these functions should 
# be used depends on the layout of the data,  that the user defined function should be applied on. 

# ## Apply a function on every element of a datacube

# The `map` function can be used to apply a function on every entry of a YAXArray without taking 
# the dimensions into account. This will lazily register the mapped function which is applied when 
# the YAXArray is either accessed or when more involved computations are made. 

#If we set up a dummy data cube which has all numbers between 1 and 10000.

using YAXArrays
axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", 1:100)]
original = YAXArray(axes, reshape(1:10000, (10,10,100)))

# with one at the first position:

original[1,:,1]

# now we can substract `1` from all elements of this cube
substracted = map(x-> x-1, original)

# `substracted` is a cube of the same size as `original`, and the applied function is registered, 
# so that it is applied as soon as the elements of `substracted` are either accessed or further used 
# in other computations. 
substracted[1,:,1]

# ## Apply a function along dimensions of a single cube

# If an function should work along a certain dimension of the data you can use the 'mapslices' function 
# to easily apply this function. This doesn't give you the flexibility of the `mapCube` function but it 
# is easier to use for simple functions. 

# If we set up a dummy data cube which has all numbers between 1 and 10000.
axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", 1:100)]
original = YAXArray(axes, reshape(1:10000, (10,10,100)))

# and then we would like to compute the sum over the Time dimension:
timesum = mapslices(sum, original, dims="Time")

# this reduces over the time dimension and gives us the following values
timesum[:,:]

# You can also apply a function along multiple dimensions of the same data cube. 
lonlatsum = mapslices(sum, original, dims=("Lon", "Lat"))

# ## How to combine multiple cubes in one computation


# ## Compute the Mean Seasonal Cycle for one sigle pixel
using Plots
using Dates
using Statistics

# We define the data span. For simplicity, three non-leap years were selected.
t =  Date("2021-01-01"):Day(1):Date("2023-12-31")

## create some seasonal dummy data
x = repeat(range(0, 2π, length=365), NpY)
var = @. sin(x) + 0.1 * randn()

plot(t, var, xlabel="Time", ylabel="Variable", legend=:false, lw=1.5, color=:purple)

## define the cube
axes = [RangeAxis("Time", t)]
c = YAXArray(axes, var)

# Let's calculate the mean seasonal cycle of our dummy variable 'var'

function getMSC(c)
    ## filterig by month-day
    monthday = map(x->Dates.format(x, "u-d"), collect(c.Time))
    datesid = unique(monthday)

    ## number of years
    NpY = Int(size(monthday)[1]/365)
    
    ndays = 365
    idx = Int.(zeros(ndays, NpY))

    ## get the day-month indices for data subsetting
    for i in 1:ndays
        idx[i,:] = Int.(findall(x-> x == datesid[i], monthday))
    end

    ## compute the mean seasonal cycle
    mscarray = map(x->var[x], idx)
    msc = mapslices(mean, mscarray, dims=2)
end

msc = getMSC(c)

 
## plot results
plot(datesid, var[1:365], label="2021", color=:orange, lw=1.5, ls=:dot, xlabel="Time", ylabel="Variable")
plot!(var[366:730], label="2022", color=:brown, lw=1.5, ls=:dash)
plot!(msc, label="MSC", color=:cyan, lw=2.5)

