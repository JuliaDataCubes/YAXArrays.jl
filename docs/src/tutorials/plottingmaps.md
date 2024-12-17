# Plotting maps

As test data we use the CMIP6 Scenarios.

````@example plots
using Zarr, YAXArrays, Dates
using DimensionalData
using GLMakie, GeoMakie
using GLMakie.GeometryBasics

store ="gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/"
````
````@ansi plots
g = open_dataset(zopen(store, consolidated=true))
````

````@ansi plots
c = g["tas"];
nothing # hide
````

Subset, first time step

````@ansi plots
ct1_slice = c[time = Near(Date("2015-01-01"))];
nothing # hide
````

use lookup to get axis values

````@example plots
lon = lookup(ct1_slice, :lon)
lat = lookup(ct1_slice, :lat)
data = ct1_slice.data[:,:];
nothing # hide
````

## Heatmap plot

````@example plots
GLMakie.activate!()

fig, ax, plt = heatmap(ct1_slice; colormap = :seaborn_icefire_gradient,
    axis = (; aspect=DataAspect()),
    figure = (; size = (1200,600), fontsize=24))
fig
````

# Wintri Projection
Some transformations

````@example plots
δlon = (lon[2]-lon[1])/2
nlon = lon .- 180 .+ δlon
ndata = circshift(data, (192,1))
nothing # hide
````

and add Coastlines with `GeoMakie.coastlines()`, 

````@example plots
fig = Figure(;size=(1200,600))
ax = GeoAxis(fig[1,1])
surface!(ax, nlon, lat, ndata; colormap = :seaborn_icefire_gradient, shading=false)
cl=lines!(ax, GeoMakie.coastlines(), color = :white, linewidth=0.85)
translate!(cl, 0, 0, 1000)
fig
````
## Moll projection

````@example plots
fig = Figure(; size=(1200,600))
ax = GeoAxis(fig[1,1]; dest = "+proj=moll")
surface!(ax, nlon, lat, ndata; colormap = :seaborn_icefire_gradient, shading=false)
cl=lines!(ax, GeoMakie.coastlines(), color = :white, linewidth=0.85)
translate!(cl, 0, 0, 1000)
fig
````

## 3D sphere plot

````@example plots
using GLMakie
using GLMakie.GeometryBasics
GLMakie.activate!()

ds = replace(ndata, missing =>NaN)
sphere = uv_normal_mesh(Tesselation(Sphere(Point3f(0), 1), 128))

fig = Figure(backgroundcolor=:grey25, size=(500,500))
ax = LScene(fig[1,1], show_axis=false)
mesh!(ax, sphere; color = ds'[end:-1:1,:], shading=false,
    colormap = :seaborn_icefire_gradient)
zoom!(ax.scene, cameracontrols(ax.scene), 0.5)
rotate!(ax.scene, 2.5)
fig
````

# AlgebraOfGraphics.jl

> [!NOTE]
> From [DimensionalData docs](https://rafaqz.github.io/DimensionalData.jl/stable/plots#algebraofgraphics-jl) :
>
> **AlgebraOfGraphics.jl** is a high-level plotting library built on top of Makie.jl that provides a declarative algebra for creating complex visualizations, similar to **ggplot2**'s "grammar of graphics" in R. It allows you to construct plots using algebraic operations like **(*)** and **(+)**, making it easy to create sophisticated graphics with minimal code.

````@example plots
using GLMakie
using AlgebraOfGraphics
GLMakie.activate!()
````

let's continue using the cmip6 dataset

````@example plots
c = g["tas"]
````

and let's focus on the first time step:

````@example plots
dim_data = readcubedata(c[time=1]) # read into memory first!
````

and now plot

````@example plots
data(dim_data) * mapping(:lon, :lat; color=:value) * visual(Scatter) |> draw
````

set other attributes

````@example plots
plt = data(dim_data) * mapping(:lon, :lat; color=:value)
draw(plt * visual(Scatter, marker=:rect), scales(Color = (; colormap = :plasma));
    axis = (width = 600, height = 400, limits=(0, 360, -90, 90)))
````

## Faceting

For this let's consider more time steps from our dataset:

````@example plots
using Dates
dim_time = c[time=DateTime("2015-01-01") .. DateTime("2015-01-01T21:00:00")] # subset 7 t steps
````

````@example plots
dim_time = readcubedata(dim_time); # read into memory first!
nothing # hide
````

````@example plots
plt = data(dim_time) * mapping(:lon, :lat; color = :value, layout = :time => nonnumeric)
draw(plt * visual(Scatter, marker=:rect))
````

again, let's add some additional attributes

````@example plots
plt = data(dim_time) * mapping(:lon, :lat; color = :value, layout = :time => nonnumeric)
draw(plt * visual(Scatter, marker=:rect), scales(Color = (; colormap = :magma));
    axis = (; limits=(0, 360, -90, 90)),
    figure=(; size=(900,600)))
````