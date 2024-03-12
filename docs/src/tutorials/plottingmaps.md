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
ct1_slice = c[Ti = Near(Date("2015-01-01"))];
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

````julia
using Bonito, WGLMakie
Page(exportable=true, offline=true)

WGLMakie.activate!()
Makie.inline!(true) # Make sure to inline plots into Documenter output!

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


