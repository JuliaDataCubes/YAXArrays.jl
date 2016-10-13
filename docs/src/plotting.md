```@eval
#Load Javascript env
import Patchwork
import Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```

```@setup 1
using CABLAB # hide
import Documenter
ds=RemoteCube() # hide
```

# Plotting

```@meta
CurrentModule = CABLAB.Plot
```

## Plot geographical maps

Map plotting is generally done using the `plotMAP` function:

```@docs
plotMAP
```

Here is an example on how to plot a map. The keyword arguments specify the time
step (`time=1`) and the variable (`var=1`).

```@example 1

cdata=getCubeData(ds,variable=["air_temperature_2m","gross_primary_productivity"])
plotMAP(cdata,time=1,var=1)
```

Inside a Jupyter notebook, the keyword arguments can be omitted and sliders or
dropdown menus will be shown to select the desired values.

## Other plots

Generating x-y type plots is done with the generic plotXY function.

```@docs
plotXY
```

Here are two examples for using this function:

```julia
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
nothing # hide
```

````@eval
using CABLAB # hide
import Documenter # hide
ds=RemoteCube() # hide
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
p=plotXY(cdata,xaxis="time",group="variable",lon=31,lat=51)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(takebuf_string(b))
````

This is a time series plot, grouped by variables for a specific longitude/latitude.


```julia
m=reduceCube(mean,cdata,TimeAxis)
plotXY(m,xaxis="variable",group="lat",lon=30)
```

````@eval
using CABLAB # hide
import Documenter # hide
ds=RemoteCube() # hide
cdata=getCubeData(ds,variable=["net_ecosystem_exchange","gross_primary_productivity","terrestrial_ecosystem_respiration"],
longitude=(30.0,30.0),latitude=(50.0,52.0))
m=reduceCube(mean,cdata,TimeAxis, max_cache=1e8)
p=plotXY(m,xaxis="variable",group="lat",lon=30)
b=IOBuffer()
show(b,MIME"text/html"(),p)
Documenter.Documents.RawHTML(takebuf_string(b))
````
