```@eval
#Load Javascript env
import Documenter
```

```@setup 1
using ESDL # hide
using ESDLPlots
using Dates
import Documenter
c=Cube() # hide
```

# Plotting

```@meta
CurrentModule = Main.ESDLPlots
```

## Plot geographical maps

Map plotting is generally done using the `plotMAP` function:

```@docs
plotMAP
```

Here is an example on how to plot a map. The keyword arguments specify the time
step (`time=Date(1980,1,1)`) and the variable (`var="air_temperature_2m"`).

```@example 1
using ESDL, Compose # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"])
p = plotMAP(cube,time=Date(2003,1,1), var="air_temperature_2m")
draw(SVG("p1.svg", 16cm, 10cm), p) #hide
nothing #hide
```
![](p1.svg)

Inside a Jupyter notebook, the keyword arguments can be omitted and sliders or
dropdown menus will be shown to select the desired values.

### RGB Maps

A common method to plot several variables at once in a single map is an RGB map.
This is possible through the plotMAPRGB function.

```@docs
plotMAPRGB
```


For example, if we want to plot GPP, NEE and TER as an RGB map for South America,
we can do the following:


```@example 1
using ESDL, Compose # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
using ColorTypes
p = plotMAPRGB(c,c1="gross_primary_productivity",
             c2="net_ecosystem_exchange",
             c3="terrestrial_ecosystem_respiration",
             cType=Lab,
             time=Date(2003,2,26))
draw(SVG("p2.svg", 16cm, 10cm), p) #hide
nothing #hide
```
![](p2.svg)

## Other plots

### XY plots

Generating x-y type plots where the x axis is one of the cube axes and the y axis
is the corresponding cube value is done with the generic `plotXY` function.

```@docs
plotXY
```

Here are two examples for using this function:

````@example 1
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
lon=-70,lat=-51)
p=plotXY(cube,xaxis="time",group="variable",lon=31,lat=51)
````

This is a plot showing the mean values of the chosen variables across different latitudes at 30° E


````@example 1
using ESDL, ESDLPlots
using Statistics
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"], lon = -70, lat=(-51,-49))
m = mapslices(mean ∘ skipmissing, cube, dims="time")
p=plotXY(m,xaxis="var",group="lat")
````

### Scatter plots

In order to do scatter plots, i.e. plotting variable A against variable B one can use the
`plotScatter` function.

```@docs
plotScatter
```

A short example is shown here:


````@example 1
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"])
p=plotScatter(cube,alongaxis=TimeAxis,xaxis="net_ecosystem_exchange",yaxis="gross_primary_productivity",lat=-50, lon=-70)
````
