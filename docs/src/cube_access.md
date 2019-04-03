# Accessing the Data Cube

## Open a data cube

Before one can read data from a cube, it has to be opened. To open a data cube,
which is accessible through the file system, use the [`Cube(base_dir)`](@ref Cube(base_dir::AbstractString)) constructor:

 ```julia
using ESDL
c = Cube("/path/to/cube/")
```
```
ESDL data cube at /path/to/cube/
Spatial resolution:  4320x2160 at 0.083333 degrees.
Temporal resolution: 2001-01-01T00:00:00 to 2012-01-01T00:00:00 at 8daily time steps
Variables:           aerosol_optical_thickness_1610 aerosol_optical_thickness_550 aerosol_optical_thickness_555 aerosol_optical_thickness_659 aerosol_optical_thickness_865 air_temperature_2m bare_soil_evaporation black_sky_albedo burnt_area c_emissions country_mask evaporation evaporative_stress fractional_snow_cover gross_primary_productivity interception_loss land_surface_temperature latent_energy net_ecosystem_exchange open_water_evaporation ozone potential_evaporation precipitation root_moisture sensible_heat snow_sublimation snow_water_equivalent soil_moisture surface_moisture terrestrial_ecosystem_respiration transpiration water_mask water_vapour white_sky_albedo
```

This returns a [`Cube`](@ref) object and prints some basic information (location, resolutions & variable names) about the cube.
Using [`Cube()`](@ref Cube(;resolution="low")) without any arguments will attempt to access a data cube at the path specified in the environmental variable `ENV["ESDL_CUBEDIR"]` or else try to [open a remote data cube](@ref open_rdc).

```@docs
ESDL.CubeAPI.Cube
ESDL.CubeAPI.Cube(base_dir::AbstractString)
ESDL.CubeAPI.Cube(;resolution="low")
```

## Getting a data handle

The next step after opening the data cube, is to select the extents of the data cube to be further subject to processing. The following code example serves to illustrate this step:

```@setup 1
using ESDL
c=Cube()
```

```@example 1
var = ["c_emissions", "air_temperature_2m"]
time = (Date("2001-01-01"), Date("2001-12-31"))
lons = (30,32), lats = (50,51)
cubedata = getCubeData(c, longitude=lons, latitude=lats, time=time, variable=var)
```
```
Data Cube view with the following dimensions
Lon                 Axis with 8 Elements from 30.125 to 31.875
Lat                 Axis with 4 Elements from 50.875 to 50.125
Time                Axis with 46 Elements from 2001-01-01 to 2001-12-27
Variable            Axis with 2 elements: c_emissions air_temperature_2m
Total size: 14.38 KB
```

This returns a view of the data cube, on which further calculations can be applied. The extents here are all data for the variables "c_emissions" and "air_temperature_2m" between 50° and 51° North and 30° and 32° East for the year 2001. For southern latitudes and western longitudes use negative values.
All keyword arguments default to the full range, so calling [`getCubeData()`](@ref getCubeData) without
keyword arguments will return a view of the whole data cube.

Here you can start to do calculations on your sub-cube, see either
[Analysis](@ref) for a list of methods provided by this framework or
[Applying custom functions](@ref) to apply your own functions on the cube. If you just
want to visualize the cube see this section [Plotting](@ref).

Note that the data wasn't read yet. In case you want to load some data into memory and store it in a Julia array, just use square-bracket indexing. For example, to read the first time step (2001-01-01) of the second variable (air_temperature_2m) as a Lon-Lat array, do

```@example 1
cubedata[:,:,1,2]
```
```
8×4 reshape(::Array{Union{Missing, Float32},4}, 8, 4) with eltype Union{Missing, Float32}:
 274.301  274.409  274.458  274.499
 274.299  274.411  274.473  274.529
 274.297  274.412  274.488  274.558
 274.296  274.414  274.503  274.588
 274.294  274.415  274.518  274.618
 274.28   274.412  274.533  274.649
 274.266  274.409  274.547  274.681
 274.251  274.406  274.562  274.713
```


```@docs
ESDL.CubeAPI.getCubeData
```

## [Opening Remote Data Cubes](@id open_rdc)

If you just want to try the ESDL and don't have access to the full data set, you can open a remote cube through
a THREDDS server. All you need is a working internet connection to do this:

```@docs
RemoteCube()
```

This will open the remote cube and calling [`getCubeData`](@ref) will return a cube view that you can process.

**Important** In order to avoid unnecessary traffic, be nice to our servers.
Please use this only for testing the ESDL software for a very limited amount of data (reading maps at single time steps)
or time series in lon-lat boxes of size 1° x 1°.

## Cube Types

While the [`getCubeData`](@ref) command returns an object of type [`SubCube`](@ref ESDL.CubeAPI.SubCube), which represents a view into the ESDC, other cube operations will return different types of data cubes.
The returned type will depend on the size of the returned cube. If it is small enough to fit into memory, it will be a [`CubeMem`](@ref), otherwise a [`MmapCube`](@ref ESDL.Cubes.MmapCube). All these types of data cubes share the same interface defined by [`AbstractCubeData`](@ref ESDL.AbstractCubeData), which means you can index them, do calculation using [`mapCube`](@ref) or plot them using the commands described in [Plotting](@ref).

```@docs
ESDL.AbstractCubeData
```

```@docs
ESDL.Cubes.CubeMem
```


```@docs
ESDL.CubeAPI.SubCube
```

```@docs
ESDL.CubeAPI.SubCubeV
```


```@docs
ESDL.Cubes.MmapCube
```


## Cube Dimensions

Dimensions are an essential part of each Cube in ESDL. Every dimension that a cube has is associated
with an axis that stores the values of the dimension. For example, a `LatitudeAxis` will contain a
field `values` representing the chosen latitudes. Similarly, a `VariableAxis` will contain a list of
Variable names. Axes types are divided in categorical axes and axes represented by ranges. All of them
are subtypes of the abstract type [`CubeAxis`](@ref ESDL.Cubes.Axes.CubeAxis).

```@docs
ESDL.Cubes.Axes.CubeAxis
```

```@docs
ESDL.Cubes.Axes.CategoricalAxis
```

```@docs
ESDL.Cubes.Axes.RangeAxis
```

## List of known regions

```@docs
ESDL.CubeAPI.known_regions
```
