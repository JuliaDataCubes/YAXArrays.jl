# Applying custom functions

The main feature of this package, and propbably the one one that is most different to other geospatial frameworks is the `mapCube` function that lets you execute *arbitrary* functions on *arbitrary* slices (and permutations) of one or more input data cubes. The function can be pure Julia or call into C libraries, call other packages, etc. In addition, the computation will be carried out in a memory-efficient manner, which mean, that only the data is read in a chunked manner, processed and then again written slice-by-slice to allow out-of-core computation. All this is done by the `mapCube` methods which applies a user-defined function `f` on slices of the cube. The underlying principles are:

1. The function `f` takes `N_in` arrays as input and its output is represented in `N_out` output arrays.
2. The function `f` has at least `N_out + N_in` arguments, where so its signature is `f(xout1, xout2, .... ,xoutN_out, xin1, xin2, ... xinN_in, addargs...; kwargs...)`
3. Every input array of `f` will be a slice of an input data cube. The user specifies the axes that will be used for slicing by creating an `InDims` for every input cube object and passing it to the `mapCube` function.
4. The dimensions of every output array have to be specified by the user by creating an `OutDims` object for every output cube and passing it to the `mapCube function`
5. The input data cubes may have additional dimensions which are not used for slicing, these will be iterated over and the function `f` be called repeatedly for every slice. If there are multiple input cubes, and contain additional axes of the same name, they must are required to have the same axis values, so that equal values are matched in the looped. If different input cubes have differently named additional axes, their oputer product will be applied and the axes will all be added to the output cubes.

## A minimal example

In order to understand how these principles are applied, let us walk through a very basic example, namely a function that normalizes the time series of a datacube. That means, we want to scale each time series in the cube in a way that its mean is 0 and the standard deviation is 1.Let's translate this into the principles mentioned above. Our function that we want to writes will take a 1D-array as an input (a time series) and write an output of the same length. So the function will have to accept two arguments, which we will call `xin` for the inout time series and `xout` as the placeholder for the output time series. We can define such a function like this:

```@example 1
using ESDL
using Missings
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

```@example 1
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

### Using different representations for missing data

By default, the data that are passed to the user-defined function will always be represented as an Array{Union{T,Missing}}, so they use Julia's `Missing` type to represent missing data. However, there might be several reasons for the missingnes of a single data value, like it might be in the ocean, or it is out of the dataset period or it is an observation gap. In the ESDC this information is stored in a special mask type (see [Cube Masks](@ref)), that can be accessed inside the UDF. For example, if we want to rewrite the `myNorm` function defined above, but we want to only calculate the mean and std based on values that were not gapfilled, one could do so:

```@example 1
import ESDL.Mask
function mynorm_nonfilled(xout, ain)
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

mapCube(mynorm_nonfilled, d, indims = indims, outdims = outdims, no_ocean=1)
```

Let's see what we changed. First when constructing the `InDims` object we used the `miss` keyword argument to specify that we want missing values represented by an extra mask. This tells the `mapCube` function to pass the first input cube as a tuple. Inside the function, we first destructure the tuple into the mask and the data, determine the missing and filled values from the mask and then do the computation on the filtered data. See [`InDims`](@ref) for more options on representation of missing data.

### Calculations on multiple cubes

So far we showed only examples with a single input data cube. Here we give a first example for doing operations on two input cubes having different shapes. To do this, let us go back to our `mynorm` example and assume that we do not only want to return the normalized time series but also the standard deviation and the mean. The problem here is that mean and standard deviation are scalars while the time series is a vector so they can not easily be coerced into a single output cube. The solution would be to return multiple output cubes. So we define the norm function and `Indims` and `Outdims` as follows:

```@example 1
function mynorm_return_stdm(xout_ts, xout_m, xout_s, xin)
  # Check if we have only missing values
  if all(ismissing,xin)
    xout_ts[:]=missing
    xout_m[1]=missing
    xout_s[1]=missing
  else
    m = mean(skipmissing(xin))
    s = std(skipmissing(xin))
    if s>0 # See if time series is not constant
      xout_ts[:].=(xin.-m)./s
    else #Time series is probably constant
      xout_ts[:]=0.0
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

First of all lets see what changed. We added two more arguments to the UDF, which are `xout_m` and `xout_s` the additional output arrays and we put the additional outputs into them. Then we added an additional output cube description `OutDims()` for each cube, which has no argument, because these outputs are singular values and don't contain any dimensions. When we apply the function, we simply pass a tuple of output cube descriptions to the `outdims` keywords and the mapCube function returns then three cubes: the full *time x lon x lat x variable* cube for the normalized time series and two *lon x xlat x variable* cubes for mean and standard deviation.   

Of course, this also works the same way if you want to apply a function to multiple input data cubes. Let's stay with the normalization example and assume that we want to normalize our dataset with some externally given standard deviation and mean, which are different for every pixel. Then one would have to define multiple `InDims` objects:

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

Note that the operation will match all the other axes that the cube contains, so because the cubes `d`,`m` and `s` all contain a `LonAxis`, a `LatAxis` and a `VariableAxis`, holding the same values, it will loop over these so that for every pixel the "right" mean and standard deviation is used.


### Axes are cubes

In some cases one needs to have access to the value of an axis, for example when one wants to calculate a spatial Aggregation, the latitudes
are important to determine grid cell weights. To do this, one can pass a cube axis to mapCube as if it was a cube having only one dimension. The values will then correspond to the axis values (the latitudes in degrees in this case).

```julia
using ESDL # hide
function spatialAggregation(xout::Array{T,0}, xin::Matrix, latitudes::AbstractVector) where T
  #code goes here
end

#Extract the latitude axis
latitudecube = ESDL.getAxis("Lat",cube)

indims_map = InDims(LonAxis, LatAxis)
indims_lat = InDims(LatAxis,miss=ESDL.NoMissing())
outdims    = OutDims()
mapCube(spatialAggregation, (cube,lataxis), indims = (indims_map, indims_lat), outdims = outdims);
```

Here, the function will operate on a lon x lat matrix and one has access to the latitude values inside the function.
Note that the [`getAxis`](@ref) function is very useful in this context, since it extracts the axis of a certain name from a given data cube object. Then we pass the cube axis as a second input cube to the `mapCube` function (see also [Calculations on multiple cubes](@ref)).

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

indims1  = InDims("Time",    miss=ESDL.NaNMissing())
indims2  = InDims("Time",    miss=ESDL.NaNMissing())
outdims  = OutDims(polyaxis, miss=ESDL.NaNMissing())
```

So here we don't describe the output axis through a type or name, but by passing an actual object. Then we can call the `mapCube` function:

```@example 2
c   = Cube()
gpp = getCubeData(c,variable = "gross_primary_productivity",time=(DateTime(2001),DateTime(2002,12,31)), longitude = (50,51), latitude=(30,31))
ter = getCubeData(c,variable = "terrestrial_ecosystem_respiration",time=(DateTime(2001),DateTime(2002,12,31)), longitude = (50,51), latitude=(30,31))

mapCube(fit_npoly,(gpp,ter),2,indims = (indims1,indims2), outdims = outdims)
```

Returned is a 3D cube with dimensions *coeff x lon * lat*.

### Wrapping mapCube calls into user-friendly functions

When a certain function is is used more often, it makes sense to wrap it into a single function so that the user does not have to deal with the input and output dimension description. For the polynomial regression example one could, for example, define this convenience wrapper and then call it directly, now for a third-order regression:

```@example 2
function fitpoly(cube1, cube2, n)
  polyaxis = CategoricalAxis("Coefficients",["Offset";string.(1:n)])

  indims1  = InDims("Time",    miss=ESDL.NaNMissing())
  indims2  = InDims("Time",    miss=ESDL.NaNMissing())
  outdims  = OutDims(polyaxis, miss=ESDL.NaNMissing())

  mapCube(fit_npoly,(cube1,cube2),n,indims = (indims1,indims2), outdims = outdims)
end

fitpoly(gpp,ter,3)
```

This is exactly the way the built-in functions in [Analysis](@ref) were generated. So in case you want to contribute some functionality that you feel would benefit this package, please open a pull request at https://github.com/esa-esdl/ESDL.jl

## Reference documentation for mapCube-related functions

```@docs
InDims
```

```@docs
OutDims
```

```@docs
mapCube
```
