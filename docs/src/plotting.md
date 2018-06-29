```@eval
#Load Javascript env
import Patchwork
import Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```

```@setup 1
using ESDL # hide
using ESDLPlots
import Documenter
ds=Cube() # hide
```

# Plotting

```@meta
CurrentModule = Main.ESDLPlots
```

## Plot geographical maps

Map plotting is generally done using the `plotMAP` function:

`plotMAP(cube::AbstractCubeData; dmin=datamin, dmax=datamax, colorm=colormap("oranges"), oceancol=colorant"darkblue", misscol=colorant"gray", kwargs...)`

Map plotting tool for cube objects, can be called on any type of cube data

### Keyword arguments

* `dmin, dmax` Minimum and maximum value to be used for color transformation
* `colorm` colormap to be used. Find a list of colormaps in the [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) package
* `oceancol` color to fill the ocean with, defaults to `colorant"darkblue"`
* `misscol` color to represent missing values, defaults to `colorant"gray"`
* `symmetric` make the color scale symmetric around zero
* `labels` given a list of labels this will create a plot with a non-continouous color scale where integer cube values [1..N] are mapped to the given labels.
* `dim=value` can set other dimensions to certain values, for example `var="air_temperature_2m"` will fix the variable for the resulting plot

If a dimension is neither longitude or latitude and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.

Here is an example on how to plot a map. The keyword arguments specify the time
step (`time=1`) and the variable (`var=1`).

```@example 1

cdata=getCubeData(ds,variable=["air_temperature_2m","gross_primary_productivity"])
plotMAP(cdata,time=1,var=1)
```

Inside a Jupyter notebook, the keyword arguments can be omitted and sliders or
dropdown menus will be shown to select the desired values.

### RGB Maps

A common method to plot several variables at once in a single map is an RGB map.
This is possible through the plotMAPRGB function.

`plotMAPRGB(cube::AbstractCubeData; dmin=datamin, dmax=datamax, colorm=colormap("oranges"), oceancol=colorant"darkblue", misscol=colorant"gray", kwargs...)`

Map plotting tool for colored plots that use up to 3 variables as input into the several color channels.
Several color representations from the `Colortypes.jl` package are supported, so that besides RGB (XYZ)-plots
one can create HSL, HSI, HSV or Lab and Luv plots.

### Keyword arguments

* `dmin, dmax` Minimum and maximum value to be used for color transformation, can be either a single value or a tuple, when min/max values are given for each channel
* `rgbAxis` which axis should be used to select RGB channels from
* `oceancol` color to fill the ocean with, defaults to `colorant"darkblue"`
* `misscol` color to represent missing values, defaults to `colorant"gray"`
* `labels` given a list of labels this will create a plot with a non-continouous color scale where integer cube values [1..N] are mapped to the given labels.
* `cType` ColorType to use for the color representation. Can be one of `RGB`, `XYZ`, `Lab`, `Luv`, `HSV`, `HSI`, `HSL`
* `dim=value` can set other dimensions to certain values, for example `var="air_temperature_2m"` will fix the variable for the resulting plot


If a dimension is neither longitude or latitude and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.

For example, if we want to plot GPP, NEE and TER as an RGB map for South America,
we can do the following:

```@example 1
d=getCubeData(ds,variable="Biosphere",region="South America")
using ColorTypes
plotMAPRGB(d,c1="gross_primary_productivity",
             c2="net_ecosystem_exchange",
             c3="terrestrial_ecosystem_respiration",
             cType=Lab,
             time=100)
```

## Other plots

### XY plots

Generating x-y type plots where the x axis is one of the cube axes and the y axis
is the corresponding cube value is done with the generic `plotXY` function.

```
`plotXY(cube::AbstractCubeData; group=0, xaxis=-1, kwargs...)`

Generic plotting tool for cube objects, can be called on any type of cube data.

### Keyword arguments

* `xaxis` which axis is to be used as x axis. Can be either an axis Datatype or a string. Short versions of axes names are possible as long as the axis can be uniquely determined.
* `group` it is possible to group the plot by a categorical axis. Can be either an axis data type or a string.
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the x axis or group variable and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
```

Here are two examples for using this function:

```julia
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
plotXY(cdata,xaxis="time",group="variable",lon=31,lat=51)
nothing # hide
```

````@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
ds=Cube() # hide
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
p=plotXY(cdata,xaxis="time",group="variable",lon=31,lat=51)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````

This is a time series plot, grouped by variables for a specific longitude/latitude.


```julia
m=reduceCube(mean,cdata,TimeAxis)
plotXY(m,xaxis="variable",group="lat",lon=30)
```

````@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
ds=Cube() # hide
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
m=reduceCube(mean,cdata,TimeAxis, max_cache=1e8)
p=plotXY(m,xaxis="variable",group="lat",lon=30)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````

### Scatter plots

In order to do scatter plots, i.e. plotting variable A against variable B one can use the
`plotScatter` function.

`plotScatter(cube::AbstractCubeData; vsaxis=VariableAxis, alongaxis=0, group=0, xaxis=0, yaxis=0, kwargs...)`

Generic plotting tool for cube objects to generate scatter plots, like variable `A` against variable `B`. Can be called on any type of cube data.

### Keyword arguments

* `vsaxis` determines the axis from which the x and y variables are drawn.
* `alongaxis` determines the axis along which the variables are plotted. E.g. if you choose `TimeAxis`, a dot will be plotted for each time step.
* `xaxis` index or value of the variable to plot on the x axis
* `yaxis` index or value of the variable to plot on the y axis
* `group` it is possible to group the plot by an axis. Can be either an axis data type or a string. *Caution: This will increase the number of plotted data points*
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the `vsaxis` or `alongaxis` or `group` and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.


A short example is shown here:

```julia
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
p=plotScatter(cdata,alongaxis=TimeAxis,xaxis=1,yaxis=2,group="lat",lon=30)
```

````@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
ds=Cube() # hide
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
p=plotScatter(cdata,alongaxis=TimeAxis,xaxis="net_ecosystem_exchange",yaxis="gross_primary_productivity",group="lat",lon=30.0)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````
