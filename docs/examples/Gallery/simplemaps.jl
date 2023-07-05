using Zarr, YAXArrays, Dates
using DimensionalData
using GLMakie, GeoMakie
using GLMakie.GeometryBasics

store ="gs://cmip6/CMIP6/ScenarioMIP/DKRZ/MPI-ESM1-2-HR/ssp585/r1i1p1f1/3hr/tas/gn/v20190710/"
g = open_dataset(zopen(store, consolidated=true))
c = g["tas"]

# Subset, first time step
ct1 = c[Ti = Near(Date("2015-01-01"))]
lon = ct1.lon.val
lat = ct1.lat.val
data = ct1.data[:,:];

# ## Heatmap plot

GLMakie.activate!()
fig = Figure(resolution = (1200,600))
ax = Axis(fig[1,1]; aspect = DataAspect())
heatmap!(ax, lon, lat, data; colormap = :seaborn_icefire_gradient)
fig


# ## Add Coastlines via the GeoAxis, wintri Projection
δlon = (lon[2]-lon[1])/2
nlon = lon .- 180 .+ δlon
ndata = circshift(data, (192,1))


fig = Figure(resolution = (1200,600))
ax = GeoAxis(fig[1,1])
surface!(ax, nlon, lat, ndata; colormap = :seaborn_icefire_gradient, shading=false)
cl=lines!(ax, GeoMakie.coastlines(), color = :white, linewidth=0.85)
translate!(cl, 0, 0, 1000)
fig

# ## Moll projection

fig = Figure(resolution = (1200,600))
ax = GeoAxis(fig[1,1]; dest = "+proj=moll")
surface!(ax, nlon, lat, ndata; colormap = :seaborn_icefire_gradient, shading=false)
cl=lines!(ax, GeoMakie.coastlines(), color = :white, linewidth=0.85)
translate!(cl, 0, 0, 1000)
fig

# ## 3D sphere plot

#using JSServe, WGLMakie
#WGLMakie.activate!()
#Page(exportable=true, offline=true)

ds = replace(ndata, missing =>NaN)
sphere = uv_normal_mesh(Tesselation(Sphere(Point3f(0), 1), 128))

fig = Figure()
ax = LScene(fig[1,1], show_axis=false)
mesh!(ax, sphere; color = ds'[end:-1:1,:],
    colormap = :seaborn_icefire_gradient)
zoom!(ax.scene, cameracontrols(ax.scene), 0.65)
rotate!(ax.scene, 2.5)
fig


