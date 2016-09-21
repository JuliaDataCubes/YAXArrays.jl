# Applying custom functions

It is possible for the user to register their own functions into the data cube
so that they can easily be applied through the mapCube function as if it was a built-in function.

First of all one needs to define the function that is supposed to be applied on the cube. In general, it should have the following signature:
f(x_out,m_out,x_in,m_in,addargs...), where `x_out` is the output array, `m_mout` the output mask, `x_in` is the input array and `m_in` the input mask.
This can be followed by an arbitrary number of additional arguments `addargs`.

You can read about cube masks here [Cube Masks](@ref). In case you don't want to treat the cube's mask individually, you can leave out the `m_out` arguments
and have missing values treated through DataArrays or using NaNs. Once you have defined your function, you can register it whith `registerDATFunction`

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

In order to understand better what happens, lets look at some examples. Let's assume we want to register a gap filling function which accepts single time series
and returns time series of the same length. We register the function the following way:                  

```@example
function fillGaps(xout::AbstractVector, mout::AbstractVector, xin::AbstractVector, min::AbstractVector)
  # code goes here
end

registerDATFunction(fillGaps,(TimeAxis,),(TimeAxis,))
```
