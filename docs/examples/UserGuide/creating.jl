# # Creating YAXArrays and Datasets

# ## Creating a YAXArray

using YAXArrays
using DimensionalData: DimensionalData as DD
using DimensionalData
a = YAXArray(rand(10, 20, 5))

# if not names are defined then default ones will be used, i.e. `Dim_1`, `Dim_2`.
# Get data from each Dimension with
a.Dim_1
# or with 
getproperty(a, :Dim_1)

# or even better with the `DD` `lookup` function
lookup(a, :Dim_1)

# ## Creating a YAXArray with named axis

# The two most used axis are `RangeAxis` and `CategoricalAxis`. Here, we use a combination of them
# to create a `time`, `lon` and `lat` axis and a Categorical Axis for two variables.

# ### Axis definitions
using Dates
axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"])
    )
# And the corresponding data
data = rand(30, 10, 15, 2)
ds = YAXArray(axlist, data)

# ### Select variables

ds[Variable = At("var1"), lon = DD.Between(1,2.1)]

# !!! info 
#       Please note that selecting elements in YAXArrays is done via the `DimensionalData.jl` syntax.
#       For more information checkout the (docs)[https://rafaqz.github.io/DimensionalData.jl/].


subset = ds[
    time = DD.Between( Date("2022-01-01"),  Date("2022-01-10")),
    lon=DD.Between(1,2),
    Variable = At("var2")
    ]


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
axs = (
    Dim{:lon}(range(0,1, length=10)),
    Dim{:lat}(range(0,1, length=5)),
)

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

