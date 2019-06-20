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

```julia
cube=subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"])
plotMAP(cube,time=Date(2001,1,1), var="air_temperature_2m")
```

```@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"])
p = plotMAP(cube,time=Date(2001,1,1), var="air_temperature_2m")
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
```

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

```julia
cube=subsetcube(c,variable="Biosphere",region="South America")
using ColorTypes
plotMAPRGB(cube,c1="gross_primary_productivity",
             c2="net_ecosystem_exchange",
             c3="terrestrial_ecosystem_respiration",
             cType=Lab,
             time=Date(2003,2,26))
```

```@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"])
using ColorTypes
p = plotMAPRGB(cube,c1="gross_primary_productivity",
             c2="net_ecosystem_exchange",
             c3="terrestrial_ecosystem_respiration",
             cType=Lab,
             time=Date(2003,2,26))
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
```

## Other plots

### XY plots

Generating x-y type plots where the x axis is one of the cube axes and the y axis
is the corresponding cube value is done with the generic `plotXY` function.

```@docs
plotXY
```

Here are two examples for using this function:

```julia
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,32.0),latitude=(50.0,52.0))
plotXY(cube,xaxis="time",group="variable",lon=31,lat=51)
```

````@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
lon=(30.0,32.0),lat=(50.0,52.0))
p=plotXY(cube,xaxis="time",group="variable",lon=31,lat=51)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````

This is a plot showing the mean values of the chosen variables across different latitudes at 30° E


```julia
cTable = CubeTable(value=cube,include_axes=("lat","lon","time","variable"))
m = cubefittable(cTable, WeightedMean, :value, weight=(i->cosd(i.lat)), by=(:variable, :lat, :lon))
plotXY(m,xaxis="variable",group="lat",lon=30)
```

````@eval
using ESDL # hide
using ESDLPlots
using WeightedOnlineStats
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
lon=(30.0,32.0),lat=(50.0,52.0), time=2001:2004)
cTable = CubeTable(value=cube,include_axes=("lat","lon","time","variable"))
m = cubefittable(cTable, WeightedMean, :value, weight=(i->cosd(i.lat)), by=(:variable, :lat, :lon))
p=plotXY(m,xaxis="variable",group="lat",lon=30)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````

### Scatter plots

In order to do scatter plots, i.e. plotting variable A against variable B one can use the
`plotScatter` function.

```@docs
plotScatter
```

A short example is shown here:

```julia
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
lon=(30.0,32.0),lat=(50.0,52.0))
plotScatter(cube,alongaxis=TimeAxis,xaxis="net_ecosystem_exchange",yaxis="gross_primary_productivity",lat=50, lon=30)
```

````@eval
using ESDL # hide
using ESDLPlots
gr()
import Documenter # hide
c=Cube() # hide
cube=subsetcube(c,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
lon=(30.0,32.0),lat=(50.0,52.0))
p=plotScatter(cube,alongaxis=TimeAxis,xaxis="net_ecosystem_exchange",yaxis="gross_primary_productivity",lat=50, lon=30)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(String(take!(b)))
````
