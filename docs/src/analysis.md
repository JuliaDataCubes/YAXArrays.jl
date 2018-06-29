# Elementwise calculations

Doing elementwise calculations on the cube is generally done using the `map` function. So, if you want to multiply each
single element of a data cube with 2, you could call `newcube = map(x->2*x, oldcube)`. This will not execute the computation
immediately but on the fly during the next computation or plotting. Functions with multiple arguments can also be applied like in:
`sumcube = map((x,y)->x+y, incube1, incube2)`. Which would calculate the sum of two data cubes.

We have also overloaded a list of commonly used operators (+,-,\*,/, max,min) and functions (sin,cos,exp,log, log10) to apply on
datacubes directly. So `newCube = (abs(cube1-cube2))` would work as expected.


# Analysis

The ESDL package comes with a list of predefined methods for statistical analysis.
The functions are defined to work on specific axes, for example a function that removes the
mean annual cycle will always extract one time series after the other from a cube, process them, store the results and concatenate the resulting time series to a new output cube. It does not matter which other axes are defined
in the input cube, the function will simply loop over these.

The function will then be applied to the whole cube
in a memory-efficient way, which means that chunks of data are read, processed and then saved in
the output cube. Whether the output cube is a `MmapCube` or a `CubeMem` is decided by the system,
depending on if the calculation is parallel, and how large the output cube is.

Here follows a list of analysis function included in this package. If you have implemented or wrapped a method
that might be of interest to a broader community, please feel free to open a pull request.

## Seasonal cycles

```@autodocs
Modules = [ESDL.Proc.MSC]
Private = false
```


## Outlier detection

```@autodocs
Modules = [ESDL.Proc.Outlier]
Private = false
```


## Simple Statistics

Another typical use case is the application of basic statistics like `sum`, `mean` and `std` applied on one or more cube axes.
We overload the method `mapslices` for data cubes,   

The main difference to the function exported in Base is that the dimensions to be sliced over are given by name and not by dimension index. For example,

```julia
mapslices(mean, cube,("Lon","Lat"))
```

will compute the mean over each spatial map contained in the data cube. Please that that the `mapslices` function will execute the function once with random number input to determine the shape of the returned values and then pre-allocate the output array. So keep this in mind when your function has some side-effects. Note also that although the `mapslices` function should *just work* in most cases, it is advised to know read about the [`mapCube`](@ref) function in [Applying custom functions](@ref) which gives you much more detailed control over the mapping operation.

Applying these functions makes sense if the slices one wants to reduce fit in memory. However,
if one wants to calculate some statistics on e.g. a time*lon*lat cube, one would preferably
call one of the [OnlineStats](@ref) methods.  

Additional simple statistics functions are:

```@autodocs
Modules = [ESDL.Proc.Stats]
Private = false
```


## Time series decomposition
```@autodocs
Modules = [ESDL.Proc.TSDecomposition]
Private = false
```

## Cube transformations
```@autodocs
Modules = [ESDL.Proc.CubeIO]
Private = false
```

## OnlineStats

It is possible to directly apply statistics included in the [OnlineStats.jl package](https://github.com/joshday/OnlineStats.jl)
on the data cube. This makes it possible to calculate statistics on data too big to fit into memory. The general syntax is

```julia
mapCube(f ,cube; by=CubeAxis[], cfun=identity, outAxis=nothing,kwargs...)
```

where `f` is an OnlineStat data type and `cube` is the cube you want to apply the statistics to.
By default this function will reduce all values over all axes of the cube, so if you want to do
statistics by a certain axis, it has to be specified using the `by` keyword argument.
`by` accepts a vector of axes types and up to one datacube that can serve as a mask. If such
a data cube is supplied, the statistics are split by the unique values in the mask. One can pass
a function `cfun` that transforms the mask values into an index in the range `1..N` that defines the   
index where the new value is going to be put to. If a mask is supplied, it must have either a `labels` property,
which is a `Dict{T,String}` mapping the numerical mask value to the value name. Alternatively on can supply an
`outAxis` argument that describes the resulting output axis.

This all gets clearer with two small examples. suppose we want to calculate the mean of GPP, NEE and TER
under the condition that Tair<280K and Tair>280K over all time steps and grid cells. This is achieved through the
following lines of code:

```julia
import OnlineStats
lons  = (30,31)
lats  = (50,51)
vars  = ["gross_primary_productivity","net_ecosystem_exchange","terrestrial_ecosystem_respiration"]
t     = getCubeData(ds,variable="air_temperature_2m",longitude=lons,latitude=lats)
cube  = getCubeData(ds,variable=vars,longitude=lons,latitude=lats)

splitTemp(t) = ifelse(t>280,2,1)                            # Define the classification function
outAxis      = CategoricalAxis("TempClass",["< 7C",">7C"])  # A two-length output axis, because there are two possible values
mT    = mapCube(OnlineStats.Mean,cube,by=[t,VariableAxis], cfun=splitTemp, outAxis=outAxis) # Of course we want to split by variable, too

using ESDLPlots
plotXY(mT,xaxis="var",group="tempclass")
```
```@eval
#Load Javascript env
import Patchwork
import Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```
```@eval
using ESDL
import OnlineStats
import Documenter
ds    = Cube()
lons  = (30,31)
lats  = (50,51)
vars  = ["gross_primary_productivity","net_ecosystem_exchange","terrestrial_ecosystem_respiration"]
t     = getCubeData(ds,variable="air_temperature_2m",longitude=lons,latitude=lats)
cube  = getCubeData(ds,variable=vars,longitude=lons,latitude=lats)

splitTemp(t) = ifelse(t>280,2,1)
outAxis      = CategoricalAxis("TempClass",["< 7C",">7C"])
mT    = mapCube(OnlineStats.Mean,cube,by=[t,VariableAxis], cfun=splitTemp, outAxis=outAxis)

using ESDLPlots
gr()
p=plotXY(mT,xaxis="var",group="tempclass")
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
```

A second example would be that we want to calculate averages of the fluxes according to
a country mask.

```julia
import OnlineStats
vars  = ["gross_primary_productivity","net_ecosystem_exchange","terrestrial_ecosystem_respiration"]
m     = getCubeData(ds,variable="country_mask",longitude=lons,latitude=lats)
cube  = getCubeData(ds,variable=vars,longitude=lons,latitude=lats)

mT    = mapCube(OnlineStats.Mean,cube,by=[m,VariableAxis], cfun=splitTemp, outAxis=outAxis)
```

This will split the cube by country and variable and compute averages over the input variables.

### Online PCA

It is possible to compute a principal component analysis based on a covariance matrix obtained
through an online algorithm. The package provides a convenient way to achieve this with the
cubePCA function.

```@docs
cubePCA
```

For example, if one wants to calculate a PCA over the time dimension, you could use the following code:

### Online Histograms and quantiles

It is possible to estimate histograms and quantiles of larger-than-memory datasets using an adaptive-bin histogram algorithm. The `Base.quantile` method is overloaded for objects of type `AbstractCubeData`, so the following works:

```julia
c=Cube()
d=getCubeData(c,variable=["gross_primary_productivity","net_ecosystem_exchange"], region="Europe")
q = quantile(d,[0.1,0.9], by=[VariableAxis])
q.data
```

```
2×2 Array{Float32,2}:
 0.040161  -1.88354
 6.02323    0.552485
```

to estimate the 10% and 90% quantiles of all datapoints for each variable. Note that any additional keyword arguments to this call (like the `by` argument) are passed to the respective `mapCube` call.

 
