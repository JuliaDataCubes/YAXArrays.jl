# Analysis

The CABLAB package comes with a list of predefined methods for statistical analysis.
The functions are defined to work on specific axes, for example a function that removes the
mean annual cycle will alway work an the time axis. It does not matter which other axes are defined
in the input cube, the function will simply loop over these.
All the functions are called using the `mapCube` function.

```@docs
mapCube
```

The function will then be applied to the whole cube
in a memory-efficient way, which means that chunks of data are read, processed and then saved in
the output cube. Whether the output cube is a `TempCube` or a `CubeMem` is decided by the system,
depending on if the calculation is parallel, and how large the output cube is.

Here follows a list of analysis function included in this package. If you have implemented or wrapped a method
that might be of interest to a broader community, please feel free to open a pull request.

## Seasonal cycles

```@autodocs
Modules = [CABLAB.Proc.MSC]
Private = false
```


## Outlier detection

```@autodocs
Modules = [CABLAB.Proc.Outlier]
Private = false
```


## Simple Statistics

Another typcial use case is the application of basic statistics like `sum`, `mean` and `std`.
We provide a convenience function `reduceCube`  

```@docs
reduceCube
```

Applying these functions makes sense if the slices one wants to reduce fit in memory. However,
if one wants to calculate some statistics on e.g. a time*lon*lat cube, one would preferably
call one of the [OnlineStats](@ref) methods.  

Additional simple statistics functions are:

```@autodocs
Modules = [CABLAB.Proc.Stats]
Private = false
```


## Time series decomposition
```@autodocs
Modules = [CABLAB.Proc.TSDecomposition]
Private = false
```

## Cube transformations
```@autodocs
Modules = [CABLAB.Proc.CubeIO]
Private = false
```

## OnlineStats

It is possible to directly apply statistics included in the [OnlineStats.jl package](https://github.com/joshday/OnlineStats.jl)
on the data cube. This makes it possible to calculate statistics on data too big to fit into memory. The general syntax is

```
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

plotXY(mT,xaxis="var",group="tempclass")
```
```@eval
#Load Javascript env
import Patchwork
import Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```
```@eval
using CABLAB
import OnlineStats
import Documenter
ds    = RemoteCube()
lons  = (30,31)
lats  = (50,51)
vars  = ["gross_primary_productivity","net_ecosystem_exchange","terrestrial_ecosystem_respiration"]
t     = getCubeData(ds,variable="air_temperature_2m",longitude=lons,latitude=lats)
cube  = getCubeData(ds,variable=vars,longitude=lons,latitude=lats)

splitTemp(t) = ifelse(t>280,2,1)
outAxis      = CategoricalAxis("TempClass",["< 7C",">7C"])
mT    = mapCube(OnlineStats.Mean,cube,by=[t,VariableAxis], cfun=splitTemp, outAxis=outAxis)

p=plotXY(mT,xaxis="var",group="tempclass")
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(takebuf_string(b))
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
