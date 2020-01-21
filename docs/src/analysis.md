# Analysis

The ESDL package comes with a list of predefined methods for statistical analysis.
The functions are defined to work on specific axes. For example a function that removes the
mean annual cycle, will always extract one time series after the other from a cube, process them, store the results and concatenate the resulting time series to a new output cube. It does not matter which other axes are defined
in the input cube, the function will simply iterate over these.

The function will be applied to the whole cube
in a memory-efficient way, which means that chunks of data are read, processed and then saved in
the output cube. Whether the output cube is a [`ZarrCube`](@ref ESDL.Cubes.ZarrCube) or a [`CubeMem`](@ref) is decided by the system,
depending on parallelization and the size of the output cube.

Here follows a list of analysis functions included in this package. If you have implemented or wrapped a method,
that might be of interest to a broader community, please feel free to open a pull request.

## Built-in Functions

### Seasonal cycles

All of these functions take a data cube as an argument, process the **input axis** and replace it with the **output axis**.

```@autodocs
Modules = [ESDL.Proc.MSC]
Private = false
```

### Time series decomposition

This function takes a data cube as an argument. It adds an additional dimension to the cube and returns it. Every variable, time step and location will have a set of four values in the new dimension instead of just one.

```@autodocs
Modules = [ESDL.Proc.TSDecomposition]
Private = false
```

### Cube transformations

```@autodocs
Modules = [ESDL.Proc.CubeIO]
Private = false
```

## Simple Statistics

Another typical use case is the application of basic statistics like `sum`, `mean` and `std` applied on one or more cube axes.
We therefore overload the method `mapslices` for data cubes.

The main difference to the function exported in Base is that the dimensions to be sliced over are given by name and not by dimension index. For example,

```julia
mapslices(mean, cube, ("Lon","Lat"))
```

will compute the mean over each spatial map contained in the data cube. Please note that the `mapslices` function will execute the function once with random number input to determine the shape of the returned values and then pre-allocate the output array. Keep this in mind when your function has some side-effects. Although the `mapslices` function should *work* in most cases, it is advised to read about the [`mapCube`](@ref) function in [Applying custom functions](@ref) which gives you much more detailed control over the mapping operation.

Applying these basic statistics functions makes sense, if the slices one wants to reduce fit in memory. However,
if one wants to calculate some statistics on e.g. a *time x lon x lat* cube, one would preferably
call one of the [(Weighted-)OnlineStats](@ref) methods.  

An additional simple statistic function is:

```@autodocs
Modules = [ESDL.Proc.Stats]
Private = false
```

## (Weighted-)OnlineStats

It is possible to directly apply statistics included in the [OnlineStats.jl package](https://github.com/joshday/OnlineStats.jl), as well as the [WeightedOnlineStats.jl package](https://github.com/gdkrmr/WeightedOnlineStats.jl)
on the data cube. Thus, statistical operations on data too big to fit into memory can be handled. The way to do this, is to first create a table interface to the cube,
using the [`CubeTable`](@ref) function and then applying the required type of statistic using the [`cubefittable`](@ref) function:

```julia
cTable = CubeTable(value=cube,include_axes=("lat", "lon", "time", "variable"),fastest="variable")
outCube = cubefittable(cTable, o, :value; by=by, weight=weightfun)
```

where `o` is a (Weighted-)OnlineStat data type and `cube` is the cube you want to apply the statistics to. The parameter name `value` in the [`CubeTable`](@ref) function and the corresponding symobl `:value` in the example above can be chosen arbitrarily,
as long as they are equal in the macro and the [`cubefittable`](@ref) function.
By default the [`cubefittable`](@ref) function will reduce all values over all axes of the cube, so if you want to do
statistics grouped by variables on a certain axis, it has to be specified using the `by` keyword argument.
`by` accepts a tuple of symbols and/or functions. If the cube supplied to the macro
has more than one variable, it makes sense to at least supply `by=(:variable,)` to the
function or else values of different variables will be mixed during calculation. The use of [WeightedOnlineStats](https://github.com/gdkrmr/WeightedOnlineStats.jl) is encouraged to compensate for the increasing number of grid cells per area unit in higher latitudes.

The following two examples illustrate the use of these functions. Suppose we want to calculate the mean of GPP, NEE and TER
under the condition that Tair<280K and Tair>280K over all time steps and grid cells. This is achieved through the
following lines of code:

```@example 1
using ESDL, WeightedOnlineStats
lons  = (-71,-70)
lats  = (-51,-50)
vars  = ["gross_primary_productivity","net_ecosystem_exchange","terrestrial_ecosystem_respiration"]
c = Cube()
cube  = subsetcube(c,variable=vars,lon=lons,lat=lats)
t     = subsetcube(c,variable="air_temperature_2m",lon=lons,lat=lats)

splitTemp(t) = if !ismissing(t) if t>280 return "T>7C" else return "T<7C" end else return missing end # Define the classification function
cTable = CubeTable(value=cube,include_axes=("lat","lon","time","variable"),temp=t)
r = cubefittable(cTable, WeightedMean, :value, by=(i->splitTemp(i.temp), :variable), weight=(i->cosd(i.lat)))
```

The results can be converted to a DataFrame, since a DataCube implements the table interface.

```@example 1
using DataFrames
DataFrame(r)
```


```@docs
ESDL.DAT.CubeTable
ESDL.DAT.fittable
ESDL.DAT.cubefittable
```

### Online Histograms and quantiles

It is possible to estimate histograms and quantiles of larger-than-memory datasets using an adaptive-bin histogram algorithm. The `Base.quantile` method is overloaded for objects of type `AbstractCubeData`, so the following works to estimate the 10% and 90% quantiles of all datapoints for each variable:

```julia
using WeightedOnlineStats
c=Cube()
d=subsetcube(c,variable=["gross_primary_productivity","net_ecosystem_exchange"], region="Europe")
cTable = CubeTable(value=d,axes=("lat","lon","time","variable"))

fitCube=cubefittable(cTable, WeightedHist(20), :value, by=(:variable,), weight=(i->cosd(i.lat)))

q = quantile(fitCube,[0.1,0.9])
```

```
In-Memory data cube with the following dimensions
Quantile            Axis with 2 Elements from 0.1 to 0.9
Variable            Axis with 2 elements: gross_primary_productivity net_ecosystem_exchange
Total size: 36.0 bytes
```

```julia
q.data
```

```
2×2 Array{Union{Missing, Float64},2}:
 0.169621  -1.75922
 6.04165    0.641276
```
The `WeightedHist` call in the `cubefittable` function requires an integer argument, which sets the number of adaptive bins per histogram.

## Elementwise calculations

Doing elementwise calculations on the cube is generally done using the `map` function. A simple example is the conversion of degree Kelvin to degree Celsius. To subtract from each element of a data cube with 273.15, you can call
```julia
c=Cube()
kelvinCube = subsetcube(c, variable="air_temperature_2m", region="Europe")
celsiusCube = map(x -> x-273.15, kelvinCube)
```

```
Transformed cube Data Cube view with the following dimensions
Lon                 Axis with 172 Elements from -9.875 to 32.875
Lat                 Axis with 140 Elements from 69.875 to 35.125
Time                Axis with 1702 Elements from 1980-01-01 to 2016-12-26
Total size: 195.43 MB
```
This will not execute the computation
immediately, but on the fly during the next computation or plotting. Please note that all values in the cube will be subject to the operation. So if the cube has more than one variable, this operation will apply to the values of all variables.
The following is an example for mapping multiple values:
```julia
c=Cube()
time = (Date("2001-01-01"), Date("2001-12-31"))

firstCube = subsetcube(c, time=time, variable="precipitation")
secondCube = subsetcube(c, time=time, variable="interception_loss")
diffcube = map((x,y)->x-y, firstCube, secondCube)
```
```
Transformed cube Data Cube view with the following dimensions
Lon                 Axis with 1440 Elements from -179.875 to 179.875
Lat                 Axis with 720 Elements from 89.875 to -89.875
Time                Axis with 46 Elements from 2001-01-01 to 2001-12-27
Total size: 227.42 MB
```
This calculates the difference of two data cubes, in this case the difference of precipitation and interception. Note here, that in this case both cubes must have the exact same dimensions and the dimensions must consist of the same elements.

Common operations like the above examples can even be expressed in an easier way:  commonly used operators (+, -, \*, /, max, min) and functions (sin, cos, exp, log, log10) are overloaded and can be applied on
data cubes directly. So `celsiusCube = (kelvinCube - 273.15)` and `diffcube = abs(firstCube - secondCube)` would work as expected.

## Applying custom functions

The main feature of this package, and probably the one one that is most different to other geospatial frameworks is the [`mapCube`](@ref) function that executes *arbitrary* functions on *arbitrary* slices (and permutations) of one or more input data cubes. The function can be written in Julia or call into C libraries, call other packages, etc. In addition, the computation will be carried out in a memory-efficient manner, such that  data is read only in chunks, processed and then re-written slice-by-slice to allow out-of-core computation. The basic working principles are:

1. The user-defined function (UDF) `f` takes a number `N_in` of arrays as input and its output is represented in a number `N_out` of output arrays.
2. The function `f` has at least `N_out + N_in` arguments, where so its signature is `f(xout1, xout2, .... ,xoutN, xin1, xin2, ... xinN, addargs...; kwargs...)`
3. Every input array of `f` will be a slice of an input data cube. The user specifies the axes that will be used for slicing by creating an [`InDims`](@ref) object for every input cube object and passing it to the [`mapCube`](@ref) function.
4. The dimensions of every output array have to be specified by the user by creating an [`OutDims`](@ref) object for every output cube and passing it to the [`mapCube`](@ref) function.
5. The input data cubes may have additional dimensions which are not used for slicing, these will be iterated over and the function `f` will be called repeatedly for every slice. If there are multiple input cubes, and contain additional axes of the same name, they are required to have the same axis elements, so that these elements are matched in the loop. If different input cubes have differently named additional axes, their outer product will be applied and the axes will all be added to the output cubes.

### A minimal example

In order to understand how these principles are applied, let us walk through a very basic example, namely a function that normalizes the time series of a data cube. This means, we want to scale each time series in the cube in a way so its mean will be 0 and its standard deviation will be 1. To translate this into the principles mentioned above:
1. Our function that we want to writes will take a 1D-array as an input (a time series) and write an output of the same length.
2. So the function will have to accept two arguments, which will be called `xin` for the input time series and `xout` for the output time series. Such a function can be defined like this:

```@example 1
using ESDL

function mynorm(xout, xin)

    m = mean(skipmissing(xin))
    s = std(skipmissing(xin))

    if s > 0 # std non-zero
        xout[:].=(xin.-m)./s # elementwise calculation of normalized values
    else # time series is probably constant
        xout[:]=0
    end
end
```

Next we have to define the input dimensions for our data cube. We want the function to operate on the time axis, so we create an object:

```@example 1
indims = InDims("Time")
```

The [`InDims`](@ref) constructor takes any number of positional arguments and tries to convert them into a description of a cube axis, so you can pass it a string, an axis type or an axis itself, all of which will be matched against the axes of the input data cube. Next we define the output axis:

```@example 1
outdims = OutDims("Time")
```

Similarly to the input cube constructor, for [`OutDims`](@ref) any number of descriptors is allowed. When passed a single string or axis type, then a matching input axis will be used as the output dimension. However, when a new output axis is created by the function, other possibilities for the output axis description are possible.

Having defined these objects, we can finally load a data cube handle and apply the function, the dimension description gets passed using the `indims` and `outdims` keywords:

```@example 1
c = Cube()
d = subsetcube(c,variable = ["gross_primary_productivity", "net_ecosystem_exchange"],time=(Date(2001),Date(2002,12,31)), lon = (50,51), lat=(30,31))
d_norm = mapCube(mynorm, d, indims=indims, outdims=outdims)
```
```
In-Memory data cube with the following dimensions
Time                Axis with 92 Elements from 2001-01-01 to 2002-12-27
Lon                 Axis with 4 Elements from 50.125 to 50.875
Lat                 Axis with 4 Elements from 30.875 to 30.125
Variable            Axis with 2 elements: gross_primary_productivity net_ecosystem_exchange
Total size: 14.38 KB
```  

The resulting cube has the same dimensions like the input cube. All variables except Time were just looped over and the result was stored in a new data cube.

### Calculations on multiple cubes

The first example showed how to handle a single input- and a single output- data cube. Here we give a first example for doing an operation on two output cubes having different shapes. To do this, let's go back to the `myNorm` example and assume that we do not only want to return the normalized time series but also the standard deviation and the mean of each time series. The problem is, that mean and standard deviation are scalars while the time series is a vector so they can not easily be coerced into a single output cube. The solution is to return multiple output cubes. So we define the norm function and `Indims` and `Outdims` as follows:

```@example 1
function mynorm_return_stdm(xout_ts, xout_m, xout_s, xin)
  # Check if we have only missing values
  if all(ismissing,xin)
    xout_ts[:].=missing
    xout_m[1]=missing
    xout_s[1]=missing
  else
    m = mean(skipmissing(xin))
    s = std(skipmissing(xin))
    if s>0 # See if time series is not constant
      xout_ts[:].=(xin.-m)./s
    else #Time series is probably constant
      xout_ts[:].=0.0
    end
    # Now write mean and std to output
    xout_s[1]=s
    xout_m[1]=m
  end
end

indims     = InDims("Time")
outdims_ts = OutDims("Time")
outdims_m  = OutDims()
outdims_s  = OutDims()

d_norm, m, s = mapCube(mynorm_return_stdm, d, indims=indims, outdims=(outdims_ts, outdims_m, outdims_s))
```
```
(Memory mapped cube with the following dimensions
Time                Axis with 506 Elements from 2001-01-01 to 2011-12-27
Lon                 Axis with 172 Elements from -9.875 to 32.875
Lat                 Axis with 140 Elements from 69.875 to 35.125
Variable            Axis with 2 elements: gross_primary_productivity transpiration
Total size: 116.2 MB
, In-Memory data cube with the following dimensions
Lon                 Axis with 172 Elements from -9.875 to 32.875
Lat                 Axis with 140 Elements from 69.875 to 35.125
Variable            Axis with 2 elements: gross_primary_productivity transpiration
Total size: 235.16 KB
, In-Memory data cube with the following dimensions
Lon                 Axis with 172 Elements from -9.875 to 32.875
Lat                 Axis with 140 Elements from 69.875 to 35.125
Variable            Axis with 2 elements: gross_primary_productivity transpiration
Total size: 235.16 KB
)
```

First of all lets see what changed. We added two more arguments to the UDF, which are the additional output arrays `xout_m` and `xout_s`. They contain the additional output cubes. Then we added an additional output cube description `OutDims()` for each cube, which has no argument, because these outputs are singular values (mean and standard deviation per location and variable) and don't contain any dimensions. When we apply the function, we simply pass a tuple of output cube descriptions to the `outdims` keyword and the mapCube function returns then three cubes: the full *(time x lon x lat x variable)* cube for the normalized time series and two *(lon x lat x variable)* cubes for mean and standard deviation.   

Of course, this also works the same way if you want to apply a function to multiple input data cubes. To stay with the normalization example, we assume that we want to normalize our dataset with some externally given standard deviation and mean, which are different for every pixel. Then multiple `InDims` objects have to be defined:

```@example 1
indims_ts = InDims("Time")
indims_m  = InDims()
indims_s  = InDims()
outdims   = OutDims("Time")
```

and define the function that does the scaling, which accepts now additional arguments for the scaling and offset:

```@example 1
function mynorm_given_stdm(xout, xin_ts, m, s)
  xout[:]=(xin_ts[:].-m[1])./s[1]
end

mapCube(mynorm_given_stdm, (d,m,s), indims = (indims_ts, indims_m, indims_s), outdims = outdims)
```
```
Memory mapped cube with the following dimensions
Time                Axis with 506 Elements from 2001-01-01 to 2011-12-27
Lon                 Axis with 172 Elements from -9.875 to 32.875
Lat                 Axis with 140 Elements from 69.875 to 35.125
Variable            Axis with 2 elements: gross_primary_productivity transpiration
Total size: 116.2 MB
```
Note that the operation will attempt to match the axes that the cubes contain. Because the cubes `d`,`m` and `s` all contain a `LonAxis`, a `LatAxis` and a `VariableAxis` with the same values, it will loop over these, so at every pixel the corresponding mean and standard deviation values are used.


### Axes are cubes

In some cases one needs to have access to the value of an axis. For example when one wants to calculate a spatial aggregation, the latitudes
are important to determine grid cell weights. To do this, one can pass a cube axis to mapCube as if it was a cube having only one dimension. The values will then correspond to the axis values (the latitudes in degrees in this case).

```julia
using ESDL # hide
function spatialAggregation(xout::Array{T,0}, xin::Matrix, latitudes::AbstractVector) where T
  #code goes here
end

#Extract the latitude axis
latitudecube = ESDL.getAxis("Lat",cube)

indims_map = InDims(LonAxis, LatAxis)
indims_lat = InDims(LatAxis)
outdims    = OutDims()
mapCube(spatialAggregation, (cube,latitudecube), indims = (indims_map, indims_lat), outdims = outdims);
```

Here, the function will operate on a *(lon x lat)* matrix and one has access to the latitude values inside the function.
Note that the [`getAxis`](@ref) function is very useful in this context, since it extracts the axis of a certain name from a given data cube object. Then we pass the cube axis as a second input cube to the `mapCube` function (see also [Calculations on multiple cubes](@ref)).

### Passing additional arguments

If a function call needs additional arguments, they are simply appended to the `mapCube` call and then get passed to the function. For example, if one wants
to apply a multivariate extreme event detection method `detectExtremes`, where one can choose from several methods, the function signature would look like this:

```julia
function detectExtremes(xout, xin, method_name)
  #code goes here
end

inAxes  = InDims(TimeAxis,VariableAxis)
outAxes = OutDims(TimeAxis)
method = "KDE"
mapCube(detectExtremes, d, method, indims = inAxes, outdims = outAxes);
```

The method would then be called e.g. with which would pass the String `"KDE"` as the third positional argument to the function.


### Generating new output axes

So far in our examples we always re-used axes from the input cube as output cube axes. However, it is possible to create new axes and use them for the resulting data cubes from a `mapCube` operation. The example we want to look at is a polynomial regression between two variables. Assume we want to describe the relationship between GPP and ecosystem respiration for each pixel through a polynomial of degree N.

So for each pixel we want to do the polynomial regression on the two variables and then return a vector of coefficients. We define the function that does the calculation as:

```@example 2
using ESDL
using Polynomials
function fit_npoly(xout, var1, var2, n)
  p = polyfit(var1, var2, n)
  xout[:] = coeffs(p)
end
```

Now assume we want to fit a polynomial of order 2 to our variables. We first create the output axis we want to use, you can either use [`CategoricalAxis`](@ref) for non-continuous quantities or [`RangeAxis`](@ref) for continuous axes. Here we create a categorical Axis and pass it to the OutDims constructor:

```@example 2
polyaxis = CategoricalAxis("Coefficients",["Offset","1","2"])

indims1  = InDims("Time")
indims2  = InDims("Time")
outdims  = OutDims(polyaxis)
```

So here we don't describe the output axis through a type or name, but by passing an actual object. Then we can call the `mapCube` function:

```@example 2
c   = Cube()
gpp = subsetcube(c,variable = "gross_primary_productivity",time=(Date(2001),Date(2002,12,31)), lon = (50,51), lat=(30,31))
ter = subsetcube(c,variable = "terrestrial_ecosystem_respiration",time=(Date(2001),Date(2002,12,31)), lon = (50,51), lat=(30,31))

mapCube(fit_npoly,(gpp,ter),2,indims = (indims1,indims2), outdims = outdims)
```

```
In-Memory data cube with the following dimensions
Coefficients        Axis with 3 elements: Offset 1 2
Lon                 Axis with 4 Elements from 50.125 to 50.875
Lat                 Axis with 4 Elements from 30.875 to 30.125
Total size: 240.0 bytes
```

Returned is a 3D cube with dimensions *coeff x lon x lat*.

### Wrapping mapCube calls into user-friendly functions

When a certain function is used more often, it makes sense to wrap it into a single function so that the user does not have to deal with the input and output dimension description. For the polynomial regression example one could, for example, define this convenience wrapper and then call it directly, now for a third-order regression:

```@example 2
function fitpoly(cube1, cube2, n)
  polyaxis = CategoricalAxis("Coefficients",["Offset";string.(1:n)])

  indims1  = InDims("Time")
  indims2  = InDims("Time")
  outdims  = OutDims(polyaxis)

  mapCube(fit_npoly,(cube1,cube2),n,indims = (indims1,indims2), outdims = outdims)
end

fitpoly(gpp,ter,3)
```
```
In-Memory data cube with the following dimensions
Coefficients        Axis with 4 elements: Offset 1 2 3
Lon                 Axis with 4 Elements from 50.125 to 50.875
Lat                 Axis with 4 Elements from 30.875 to 30.125
Total size: 320.0 bytes
```


This is exactly the way the built-in functions in [Analysis](@ref) were generated. So in case you want to contribute some functionality that you feel would benefit this package, please open a pull request at https://github.com/esa-esdl/ESDL.jl

### Reference documentation for mapCube-related functions

```@docs
ESDL.DAT.InDims
```

```@docs
ESDL.DAT.OutDims
```

```@docs
ESDL.DAT.mapCube
```
