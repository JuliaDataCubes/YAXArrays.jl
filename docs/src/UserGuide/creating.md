# Creating YAXArrays and Datasets

Here, we use `YAXArray` when the variables share dimensions and `Dataset` otherwise.

## Creating a YAXArray

````@example creating
using YAXArrays
using DimensionalData: DimensionalData as DD
using DimensionalData
````

````@ansi creating
a = YAXArray(rand(10, 20, 5))
````

if no names are defined then default ones will be used, i.e. `Dim_1`, `Dim_2`.

Get data from each Dimension with

````@example creating
a.Dim_1
````

or with 

````@example creating
getproperty(a, :Dim_1)
````

or even better with the `DD` `lookup` function

````@example creating
lookup(a, :Dim_1)
````

## Creating a YAXArray with named axis

The two most used axis are `RangeAxis` and `CategoricalAxis`. Here, we use a combination of them to create a `time`, `lon` and `lat` axis and a Categorical Axis for two variables.

### Axis definitions

````@ansi creating
using Dates
axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"])
    )
````

And the corresponding data

````@example creating
data = rand(30, 10, 15, 2);
nothing # hide
````

then, the `YAXArray` is

````@ansi creating
ds = YAXArray(axlist, data)
````

### Select variables

````@ansi creating
ds[Variable = At("var1"), lon = DD.Between(1,2.1)]
````

!!! info 
       Please note that selecting elements in YAXArrays is done via the `DimensionalData.jl` syntax.
       For more information checkout the [docs](https://rafaqz.github.io/DimensionalData.jl/dev/).


````@ansi creating
subset = ds[
    time = DD.Between( Date("2022-01-01"),  Date("2022-01-10")),
    lon=DD.Between(1,2),
    Variable = At("var2")
    ]
````

### Properties / Attributes

You might also want to add additional properties to your YAXArray. This can be done via a Dictionary, namely

````@example creating
props = Dict(
    "time" => "days",
    "lon" => "longitude",
    "lat" => "latitude",
    "var1" => "first variable",
    "var2" => "second variable",
);
nothing # hide
````

Then the `yaxarray` with properties is assemble with

````@ansi creating
ds = YAXArray(axlist, data, props)
````

Access these properties with

````@example creating
ds.properties
````

Note that this properties are shared for both variables `var1` and `var2`.
Namely, this are global properties for your `YAXArray`. 
However, in most cases you will want to pass properties for each variable, here we will do this via Datasets.

## Creating a Dataset

Let's define first some range axis

````@ansi creating
axs = (
    Dim{:lon}(range(0,1, length=10)),
    Dim{:lat}(range(0,1, length=5)),
)
````

And two toy random `YAXArrays` to assemble our dataset

````@ansi creating
t2m = YAXArray(axs, rand(10,5), Dict("units" => "K", "reference" => "your references"))
prec = YAXArray(axs, rand(10,5), Dict("units" => "mm", "reference" => "your references"))
````

Then the `Dataset` is assembled as

````@ansi creating
ds = Dataset(t2m=t2m, prec= prec, num = YAXArray(rand(10)),
    properties = Dict("space"=>"lon/lat", "reference" => "your global references"))
````

::: tip

Note that the YAXArrays used not necessarily shared the same dimensions.
Hence, using a Dataset is more versatile than a plain YAXArray. 

:::

## Selected Variables in a Data Cube

Being able to collect variables that share dimensions into a data cube is possible with

````@ansi creating
c = Cube(ds[["t2m", "prec"]])
````

or simply the one that does not share all dimensions

````@ansi creating
Cube(ds[["num"]])
````

### Variable properties

Access to variables properties is done via

````@example creating
Cube(ds[["t2m"]]).properties
````

and 

````@example creating
Cube(ds[["prec"]]).properties
````

Note also that the global properties for the Dataset are accessed with

````@example creating
ds.properties
````

Saving and different chunking modes are discussed [here](/UserGuide/setchuncks).

