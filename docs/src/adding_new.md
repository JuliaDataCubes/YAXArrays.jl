# Applying custom functions

## registerDATFunction

It is possible for the user to register their own functions into the data cube
so that they can easily be applied through the mapCube function as if it was a built-in function.

First of all one needs to define the function that is supposed to be applied on the cube. In general, it should have the following signature:
`f(x_out,m_out,x_in,m_in,addargs...)`, where `x_out` is the output array, `m_mout` the output mask, `x_in` is the input array and `m_in` the input mask.
This can be followed by an arbitrary number of additional arguments `addargs`.

You can read about cube masks here [Cube Masks](@ref). In case you don't want to treat the cube's mask individually, you can leave out the `m_out` arguments
and have missing values treated through DataArrays or using NaNs. Once you have defined your function, you can register it with `registerDATFunction`

In most processing frameworks of this kind, you have some kind of apply function that you pass your function to and specify the dimension number of your
array that you want to slice. Here we take a different approach. Our datacubes have named axes and usually a function is supposed to be applied on slices
of a certain axis type. For example, a time series decomposition will always be applied along the time dimension. So we register the function once so that the system
knows which named dimension the function is applied to, and the apply function will work on cubes of any shape, as long as they contain a time dimension.
The same works for combinations of dimensions. Lets suppose you want to apply a multivariate event detection method on all multivariate time series in a cube
and your function happens to need a Variable x Time Matrix as an input. You can specify this in `registerDATFunction` and then the system will automatically
read slices of the cube efficiently (transposed if necessary). The only limitation currently is that a slice of data that needs to be processed must fit in memory.
It is not (yet) possible to perform operations requiring random array access on the whole cube. The signature of `registerDATFunction` is the following:

```@doc
registerDATFunction
```

## Examples

### Simple registration

In order to understand better what happens, lets look at some examples. We want to register a gap filling function which accepts single time series
and returns time series of the same length. We register the function the following way:                  

```@example
using CABLAB # hide
function fillGaps(xout::Vector, mout::Vector{UInt8}, xin::Vector, min::Vector{UInt8})
  # code goes here
end

inAxes  = (TimeAxis,)
outAxes = (TimeAxis,)
registerDATFunction(fillGaps,inAxes,outAxes);
```

After this you can apply your function like this `mapCube(fillGaps, cubedata)`, where `cubedata` can be any type of cube, the only condition is that it must contain a `TimeAxis`.  

### Using missing for missing data

In the next example we assume want to register a function that calculates the time variance of a variable. Internally we want to use the `StatsBase` methods to
calculate the variance in the presence of missing data. To do this, the input data is best represented as `missing` form the Missing package. We register the function in the following way:

```@example
using CABLAB # hide
using DataArrays
function timeVariance{T}(xout::Array{T,0}, xin::DataVector)
  xout[1]=var(xin,skipmissing=true)
end

inAxes  = (TimeAxis,)

registerDATFunction(timeVariance, inAxes, (), inmissing=(:data,), outmissing=:data, no_ocean=1);
```

Here, the only input axis is again the time axis. However, the output axis is an empty tuple, which means that a single value is returned by the function and written
to the 0-dimensional array `xout`. The optional argument `inmissing` is a tuple of symbols, here it is length one because there is only a single input cube.
When `:data` is chosen, missing values in the cube will be converted to `missing`s in the function's input array. The same hold true for the `outmissing` argument.
Any `missing` value in the output array will be converted to a missing value in the resulting cube's mask.

There is one additional optional argument set, `no_ocean=1`. This tells the kernel to check the landsea mask if a certain value is an ocean point and not enter
the calculation for these points, but to just set the resulting mask to `OCEAN`. Please notice also that simple statistics can be done more conveniently using the
[`reduceCube`](@ref) function.

### Passing additional arguments

If a function call needs additional arguments, they are simple appended to the `mapCube` call and then get passed to the registered function. For example, if one wants
to register a multivariate extreme event detection method `detectExtremes`, where one can choose from several methods, the function signature would look like this:

```@example
using CABLAB # hide
function detectExtremes(xout::Vector, xin::Matrix, method)
  #code goes here
end

inAxes  = (TimeAxis,VariableAxis)
outAxes = (TimeAxis,)
registerDATFunction(detectExtremes, inAxes, outAxes, inmissing=(:nan,), outmissing=:nan, no_ocean=1);
```

The method would then be called e.g. with `mapCube(fillGaps, cubedata, "KDE")` which would pass the String `"KDE"` as the third positional argument to the registered function.

### Determine additional arguments from cube properties

Sometimes the registered function depends on additional arguments that are not user-supplied, but determined based on some properties of the input data cube. For example, a function that
removes the mean annual cycle from a time series might have the following signature:

```@example
using CABLAB # hide
function removeMSC(xout,xin,NpY,xmsc)
  #code
end
```

Here `NpY` is the number of time steps per year. `xmsc` is a temporary array where the mean annual cycle is stored before subtraction. For better performance
it makes sense to allocate this array once and then re-use it for each grid cell and variable instead of allocating new space at each iteration. Now there are two
choices, we either let the user determine these two additional function arguments or we write a callback function that does this automatically. Here is an example:

```@example
using CABLAB # hide
function prepareArgs(cubes, pargs)
  timeAxis = CABLAB.DAT.getAxis(TimeAxis,cube[1])
  npy = timeAxis.values.NPY
  xmsc = zeros(Float32,npy)
  return npy,xmsc
end;
```

The callback function accepts two arguments, a tuple of input cubes (`cubes`) and the arguments supplied to `mapCube` by the user (`pargs`).  It returns a tuple of
arguments that are appended to each call of the registered function. So we can register the `removeMSC` function the following way:

```@example
using CABLAB # hide
function prepareArgs(cubes, pargs) # hide
  timeAxis = CABLAB.DAT.getAxis(TimeAxis,cube[1]) # hide
  npy = timeAxis.values.NPY # hide
  xmsc = zeros(Float32,npy) # hide
  return npy,xmsc # hide
end; # hide
inAxes  = (TimeAxis,)
outAxes = (TimeAxis,)
registerDATFunction(removeMSC, inAxes, outAxes, prepareArgs, inmissing=(:nan,), outmissing=:nan);
```

Now the user can apply the function on the whole cube using `mapCube(removeMSC, cubedata)` without caring about getting the number of time steps or pre-allocating the intermediate array.

### Calculations on multiple cubes

So far we showed only examples with a single input data cube. Here we give a first example for doing operations on two input cubes having different shapes.
Let's say we have a model that predicts the biospheric CO2 uptake over a given time range based on the data cube `cubedata`, which has the axes lon x lat x time x variable.
This model depends on the vegetation type of each grid cell, which is a static variable and stored in a second data cube `staticdata` with the axes lon x lat.
Registering the function is quite straightforward:

```@example
using CABLAB # hide
function predictCarbonSink{T,U}(xout::Array{T,0}, xin::Matrix, vegmask::Array{U,0})
  #Code goes here
end
inAxes=((TimeAxis, VariableAxis), ())
outAxes=()
registerDATFunction(predictCarbonSink, inAxes, outAxes, no_ocean=2);
```

The input axes `inAxes` is now a tuple of tuples, one for each input cube. From `cubedata` we want to extract the whole time series of all variables, while
from `staticdata` we only need one value for the current pixel. When calling this function, make sure to put the input cubes into a tuple
(`mapCube(predictCarbonSink,(cubedata, staticdata))`). Note that we set the optional argument `no_ocean=2` This means that, again, ocean grid cells are skipped,
but the `2` denotes that this time the second input cube will be checked for ocean cells, not the first one.

### Even Axes are cubes

In some cases one needs to have access to the value of an axis, for example when one wants to calculate a spatial Aggregation, the latitudes
are important to determine grid cell weights. To do this, one can pass a cube axis to mapCube as if it was a cube having only one dimension.

```@example
using CABLAB # hide
function spatialAggregation{T}(xout::Array{T,0}, xin::Matrix, latitudes::AbstractVector)
  #code goes here
end

inAxes=((LonAxis, LatAxis), (LatAxis,))
outAxes=()
registerDATFunction(spatialAggregation, inAxes, outAxes, inmissing=(:data,:nan), outmissing=:data);
```

Here, the function will operate on a lon x lat matrix and one has access to the latitude values inside the function.
For the second input cube the input axis we extract the latitude axis from the first
user-supplied cube and pass it to the calculation as a second input cube. So we apply the function using:
`mapCube(spatialAggregation, (cubedata, CABLAB.DAT.getAxis(LatAxis, cubedata))`.

### Determine output axis from cube properties

For some calculations the output axis does not equal any of the input axis, but has to be generated before the cube calculation starts.
You can probably guess that this will happen through callback functions again, which have the same form as in the other examples.
In this example we want to register a function that does a polynomial regression between time series of two variables. The result of this calculation
are the regression parameters, so the output axis will be a newly created `Parameter`-axis (see [Cube Axes](@ref)). For the axis we define a default constructor which names
the fitting parameters. In this example we create a ParameterAxis for a quadratic regression.

```@example
using CABLAB # hide
function ParameterAxis(order::Integer)
  order > 0 || error("Regression must be at least linear")
  CategoricalAxis("Parameter",["offset";["p$i" for i=1:order]])
end
ParameterAxis(2)
```

Now we can go and register the function, while we specify the output axis with a function calling the Axis constructor.

```@example
using CABLAB # hide
function ParameterAxis(order::Integer) # hide
  order > 0 || error("Regression must be at least linear") # hide
  ParameterAxis(["offset";["p$i" for i=1:order]]) # hide
end # hide
function polyRegression(xout::Vector, xin::Matrix, order::Integer)
  #code here
end

inAxes=(TimeAxis,)
outAxes=((cube,pargs)->ParameterAxis(pargs[1]),)
registerDATFunction(polyRegression, inAxes, outAxes, inmissing=(:nan,), outmissing=:nan);
```

The user can apply the function now using `mapCube(polyRegression, cubedata, regOrdeer)` where `regOrder` is the order of the
Regression.
