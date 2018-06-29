# Applying custom functions

The main feature of this package, and propbably the one one that is most different to other geospatial frameworks is the `mapCube` function that lets you execute *arbitrary* functions on *arbitrary* slices (and permutations) of one or more input data cubes. The function can be pure Julia or call into C libraries, call other packages, etc. In addition, the computation will be carried out in a memory-efficient manner, which mean, that only the data is read in a chunked manner, processed and then again written slice-by-slice to allow out-of-core computation. All this is done by the `mapCube` methods which applies a user-defined function `f` on slices of the cube. The underlying principles are:

1. The function `f` takes `N_in` arrays as input and its output is represented in `N_out` output arrays.
2. The function `f` has at least `N_out + N_in` arguments, where so its signature is `f(xout1, xout2, .... ,xoutN_out, xin1, xin2, ... xinN_in, addargs...; kwargs...)`
3. Every input array of `f` will be a slice of an input data cube. The user specifies the axes that will be used for slicing by creating an `InDims` for every input cube object and passing it to the `mapCube` function.
4. The dimensions of every output array have to be specified by the user by creating an `OutDims` object for every output cube and passing it to the `mapCube function`
5. The input data cubes may have additional dimensions which are not used for slicing, these will be iterated over and the function `f` be called repeatedly for every slice. If there are multiple input cubes, and contain additional axes of the same name, they must are required to have the same axis values, so that equal values are matched in the looped. If different input cubes have differently named additional axes, their oputer product will be applied and the axes will all be added to the output cubes.

### A minimal example

In order to understand how these principles are applied, let us walk through a very basic example, namely a function that normalizes the time series of a datacube. That means, we want to scale each time series in the cube in a way that its mean is 0 and the standard deviation is 1.Let's translate this into the principles mentioned above. Our function that we want to writes will take a 1D-array as an input (a time series) and write an output of the same length. So the function will have to accept two arguments, which we will call `xin` for the inout time series and `xout` as the placeholder for the output time series. We can define such a function like this:

```@example 1
using ESDL
function mynorm(xout, xin)
  all(ismissing,xin) && return xout[:]=missing
  m = mean(skipmissing(xin))
  s = std(skipmissing(xin))
  if s>0
    xout[:].=(xin.-m)./s
  else #Time series is probably constant
    xout[:]=0
  end
  nothing
end
```

Next we have to define the input dimensions for our data cube. We want the function to operate on the time axis, so we create an object:

```@example 1
indims = InDims("Time")
```

The [`InDims`](@ref) constructor takes any number of positional arguments and tries to convert them into a description of a cube axis, so you can pass it a string, an axis type or an axis itself, all of which will be matched against the axes of the input data cube. Next we define the output axis:

```example 1
outdims = OutDims("Time")
```

Similarly to the input cube constructor, for [`OutDims`](@ref) any number of descriptors is allowed. When passed a single string or axis type, then a matching input axis will be used as the output dimension. However, when a new output axis is created by the function, other possibilities for the output axis description are possible.

Having defined these objects, we can finally load a data cube handle and apply the function, the dimension description gets passed using the `indims` and `outdims` keywords:

```@example 1
c = Cube()
d = getCubeData(c,variable = ["gross_primary_productivity", "net_ecosystem_exchange"],time=(DateTime(2001),DateTime(2002,12,31)), longitude = (50,51), latitude=(30,31))
d_norm = mapCube(mynorm, d, indims=indims, outdims=outdims)
```  

The resulting cube has the same dimensions like the input cube. All variables except Time were just looped over and the result was stored in a new data cube.


## Examples

### Using different representations for missing data

By default, the data that are passed to the user-defined function will always be represented as an Array{Union{T,Missing}}, so they use Julia's `Missing` type to represent missing data. However, there might be several reasons for the missingnes of a single data value, like it might be in the ocean, or it is out of the dataset period or it is an observation gap. In the ESDC this information is stored in a special mask type (see [Cube Masks](@ref)), that can be accessed inside the UDF. For example, if we want to rewrite the `myNorm` function defined above, but we want to only calculate the mean and std based on values that were not gapfilled, one could do so:

```julia
import ESDL.Mask
function mynorm(xout, ain)
  #Destructure the tuple into the data and mask array
  xin,min = ain
  #Get the valid data points that are not filled
  validx = find(i->Mask.isvalid(i) && !Mask.isfilled(i),min)
  # Check if we have valid points at all
  isempty(validx) && return xout[:]=missing
  #Filter data
  xin = xin[validx]
  m = mean(xin)
  s = std(xin)
  if s>0
    xout[:].=(xin.-m)./s
  else #Time series is probably constant
    xout[:]=0
  end
  nothing
end


indims  = InDims("time",miss = ESDL.MaskMissing())
outdims = OutDims("time")

mapCube(mynorm, d, indims = indims, outdims = outdims, no_ocean=1)
```

Let's see what we changed. First when constructing the `InDims` object we used the `miss` keyword argument to specify that we want missing values represented by an extra mask. This tells the `mapCube` function to pass the first input cube as a tuple instead of as a DataArray. Inside the function, we first destructure the tuple into the mask and the data, determine the missing and filled values from the mask and then do the computation on the filtered data. See [`InDims`](@ref) for more options on representation of missing data.

### Passing additional arguments

If a function call needs additional arguments, they are simple appended to the `mapCube` call and then get passed to the function. For example, if one wants
to apply a multivariate extreme event detection method `detectExtremes`, where one can choose from several methods, the function signature would look like this:

```julia
function detectExtremes(xout::Vector, xin::Matrix, method)
  #code goes here
end

inAxes  = InDims(TimeAxis,VariableAxis,miss = NaNMissing())
outAxes = OutDims(TimeAxis,miss=NaNMissing())
methods = "KDE"
mapCube(detectExtremes, cube, "KDE", indims = inAxes, outdims = outAxes, no_ocean=1);
```

The method would then be called e.g. with which would pass the String `"KDE"` as the third positional argument to the function.

### Calculations on multiple cubes

So far we showed only examples with a single input data cube. Here we give a first example for doing operations on two input cubes having different shapes.
Let's say we have a model that predicts the biospheric CO2 uptake over a given time range based on the data cube `cubedata`, which has the axes lon x lat x time x variable.
This model depends on the vegetation type of each grid cell, which is a static variable and stored in a second data cube `staticdata` with the axes lon x lat.
We call the function like this:

```julia
using ESDL # hide
function predictCarbonSink{T,U}(xout::Array{T,0}, xin::Matrix, vegmask::Array{U,0})
  #Code goes here
end
inAxes=(InDims(TimeAxis, VariableAxis),InDims())
outAxes=OutDims()
mapCube(predictCarbonSink, (cube, vegmask), indims = inAxes, outdims = outAxes, no_ocean=2);
```

The input cubes `inAxes` is now a tuple `InDims`, one for each input cube. From `cubedata` we want to extract the whole time series of all variables, while
from `staticdata` we only need one value for the current pixel. When calling this function, make sure to put the input cubes into a tuple
(`mapCube(predictCarbonSink,(cubedata, staticdata))`). Note that we set the optional argument `no_ocean=2` This means that, again, ocean grid cells are skipped,
but the `2` denotes that this time the second input cube will be checked for ocean cells, not the first one.

### Axes are cubes

In some cases one needs to have access to the value of an axis, for example when one wants to calculate a spatial Aggregation, the latitudes
are important to determine grid cell weights. To do this, one can pass a cube axis to mapCube as if it was a cube having only one dimension.

```julia
using ESDL # hide
function spatialAggregation{T}(xout::Array{T,0}, xin::Matrix, latitudes::AbstractVector)
  #code goes here
end

indims=(InDims(LonAxis, LatAxis,miss=DataArrayMissing()), InDims(LatAxis,miss=ESDL.NoMissing()))
outdims=OutDims()
mapCube(spatialAggregation, (cube,ESDL.getAxis("Lat",cube)), indims = indims, outdims = outdims);
```

Here, the function will operate on a lon x lat matrix and one has access to the latitude values inside the function.
For the second input cube the input axis we extract the latitude axis from the first
user-supplied cube and pass it to the calculation as a second input cube. So we apply the function using:

### Determine output axis from cube properties

For some calculations the output axis does not equal any of the input axis, but has to be generated before the cube calculation starts.
You can probably guess that this will happen through callback functions again, which have the same form as in the other examples.
In this example we want to call a function that does a polynomial regression between time series of two variables. The result of this calculation
are the regression parameters, so the output axis will be a newly created `Parameter`-axis (see [Cube Axes](@ref)). For the axis we define a default constructor which names
the fitting parameters. In this example we create a ParameterAxis for a quadratic regression.

```@example
using ESDL # hide
function ParameterAxis(order::Integer)
  order > 0 || error("Regression must be at least linear")
  CategoricalAxis("Parameter",["offset";["p$i" for i=1:order]])
end
ParameterAxis(2)
```

Now we can go and call the function, while we specify the output axis with a function calling the Axis constructor.

```julia
using ESDL # hide
function ParameterAxis(order::Integer) # hide
  order > 0 || error("Regression must be at least linear") # hide
  ParameterAxis(["offset";["p$i" for i=1:order]]) # hide
end # hide
function polyRegression(xout::Vector, xin::Matrix, order::Integer)
  #code here
end

inAxes  = InDims(TimeAxis,miss=NaNMissing())
outAxes = OutDims((cube,pargs)->ParameterAxis(pargs[1]),miss=NaNMissing())
order = 2
mapCube(polyRegression, cube, 2, indims = inAxes, outdims = outAxes);
```

The user can apply the function now using `mapCube(polyRegression, cubedata, regOrder)` where `regOrder` is the order of the Regression.


# Reference

```@docs
InDims
```

```@docs
OutDims
```

```@docs
mapCube
```
