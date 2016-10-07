```@eval
#Load Javascript env
import Patchwork
import Documenter
Documenter.Documents.RawHTML("<script>$(Patchwork.js_runtime())</script>")
```

```@setup 1
using CABLAB # hide
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
