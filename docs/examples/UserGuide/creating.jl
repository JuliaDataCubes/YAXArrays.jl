# # Creating YAXArrays and Datasets

# ## Creating a YAXArray

using YAXArrays
a = YAXArray(rand(10, 20, 5))

# if not names are defined then default ones will be used, i.e. `Dim_1`, `Dim_2`.
# Get data from each Dimension with
a.Dim_1
# or with 
getproperty(a, :Dim_1)

# ## Creating a YAXArray with named axis

# The two most used axis are `RangeAxis` and `CategoricalAxis`. Here, we use a combination of them
# to create a `time`, `lon` and `lat` axis and a Categorical Axis for two variables.

# ### Axis definitions
using Dates
axlist = [
    RangeAxis("time", Date("2022-01-01"):Day(1):Date("2022-01-30")),
    RangeAxis("lon", range(1, 10, length=10)),
    RangeAxis("lat", range(1, 5, length=15)),
    CategoricalAxis("Variable", ["var1", "var2"])
    ]
# And the corresponding data
data = rand(30, 10, 15, 2)
ds = YAXArray(axlist, data)

# ### Select variables

ds[Variable = "var1", lon = (1,2.1)]

# ### Indexing and subsetting
# 
#   As for most array types, YAXArray also provides special indexing behavior 
#   when using the square brackets for indexing.  Assuming that `c` is a YAXArray, 
#   there are 3 different semantics to use the square brackets with, depending on 
#   the types of the arguments provided to getindex. 
#   1. **Ranges and Integers only** as for example `c[1,4:8,:]` will access the underlying data according to the provided index in index space and read the 
#   data *into memory* as a plain Julia Array. It is equivalent to `c.data[1,4:8,:]`. 
#   2. **Keyword arguments with values or Intervals** as for example `c[longitude = 30..50, time=Date(2005,6,1), variable="air_temperature"]`.
#   This always creates a *view* into the specified subset of the data and 
#   return a new YAXArray with new axes without reading the data. Intervals and
#   values are always interpreted in the units as provided by the axis values.
#   3. **A Tables.jl-compatible object** for irregular extraction of a list of points or sub-arrays and random locations. 
#   For example calling `c[[(lon=30,lat=42),(lon=-50,lat=2.5)]]` will extract data at the specified coordinates and along all additional axes into memory. 
#   It returns a new YAXArray with a new Multi-Index axis along the selected 
#   longitudes and latitudes.

# !!! info 
#       Overall, selecting elements in YAXArrays is brittle.
#       Hence using DimensionalData.jl and YAXArrayBase.jl is recomended. 

# ## Select variables with DimensionalData.jl

using DimensionalData, YAXArrayBase
# First we wrap the yaxarray into a DimArray via

dim = yaxconvert(DimArray, ds)

# Now, the syntax from DimensionalData.jl just works 

subset = dim[
    time = Between( Date("2022-01-01"),  Date("2022-01-10")),
    lon=Between(1,2),
    Variable = At("var2")
    ]

# And going back to our YAXArray view is done with

yax = yaxconvert(YAXArray, subset)

# This will be supported by default in the next release.

# ### Properties / Attributes

# You might also want to add additional properties to your YAXArray. 
# This can be done via a Dictionary, namely

props = Dict(
    "time" => "days",
    "lon" => "longitude",
    "lat" => "latitude",
    "var1" => "first variable",
    "var2" => "second variable",
)

# Then the `yaxarray` with properties is assemble with
ds = YAXArray(axlist, data, props)

# Access these properties with
ds.properties

# Note that this properties are shared for both variables `var1` and `var2`.
# Namely, this are global properties for your yaxarray. 
# However, in most cases you will want to pass properties for each variable,
# here we will do this via Datasets.

# ## Creating a Dataset
#  Let's define first some range axis
axs = [
    RangeAxis("lon", range(0,1, length=10)),
    RangeAxis("lat", range(0,1, length=5)),
]

# And two toy random `YAXArrays` to assemble our dataset

t2m = YAXArray(axs, rand(10,5), Dict("units" => "K", "reference" => "your references"))
prec = YAXArray(axs, rand(10,5), Dict("units" => "mm", "reference" => "your references"))

ds = Dataset(t2m=t2m, prec= prec, num = YAXArray(rand(10)),
    properties = Dict("space"=>"lon/lat", "reference" => "your global references"))

# Note that the YAXArrays used not necessarily shared the same dimensions.
# Hence, using a Dataset if more versatile than a plain YAXArray. 

# ### Selected Variables into a Data Cube
# Being able to collect variables that share dimensions into a data cube is possible with
c = Cube(ds[["t2m", "prec"]])

# or simply the one that does not share all dimensions

Cube(ds[["num"]])

# ### Variable properties

## Access to variables properties is done via
Cube(ds[["t2m"]]).properties

# and 
Cube(ds[["prec"]]).properties

# Note also that the global properties for the Dataset are accessed with
ds.properties

# Saving and different chunking modes are discussed in [here]().

