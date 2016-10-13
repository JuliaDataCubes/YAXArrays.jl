# Accessing the Datat Cube

## Open a datacube

Before one can read data from a cube, it has to be opened. To open a data cube
which is accesible through the file system, use the `Cube` constructor:

 ```julia
using CABLAB
c = Cube("/patch/to/cube")
```
```
CABLAB data cube at /Net/Groups/BGI/scratch/DataCube/v0.2.0/high-res/
Spatial resolution:  4320x2160 at 0.083333 degrees.
Temporal resolution: 2001-01-01T00:00:00 to 2012-01-01T00:00:00 at 8daily time steps
Variables:           aerosol_optical_thickness_1610 aerosol_optical_thickness_550 aerosol_optical_thickness_555 aerosol_optical_thickness_659 aerosol_optical_thickness_865 air_temperature_2m bare_soil_evaporation black_sky_albedo burnt_area c_emissions country_mask evaporation evaporative_stress fractional_snow_cover gross_primary_productivity interception_loss land_surface_temperature latent_energy net_ecosystem_exchange open_water_evaporation ozone potential_evaporation precipitation root_moisture sensible_heat snow_sublimation snow_water_equivalent soil_moisture surface_moisture terrestrial_ecosystem_respiration transpiration water_mask water_vapour white_sky_albedo
```

This returns a `Cube` object that contains some basics information about the cube which is printed on the screen.

## Getting a data handle

```@setup 1
using CABLAB
c=RemoteCube()
```

```@example 1
var=["c_emissions","air_temperature_2m"]
time=(DateTime("2001-01-01"),DateTime("2001-12-31"))
cubedata = getCubeData(c,longitude=(30,31),latitude=(50,51),variable=var)
```

This returns a view into the Data Cube, on which further calculations can be applied.
All keyword arguments default to the full range, so calling `getCubeData` without
keyword arguments will return a view
No data is read yet. Here you can start to do some calculations on your sub-cube, see either
[Analysis](@ref) for a list of methods provided by this framework or
[Applying custom functions](@ref) to apply your own functions on the cube. If you just
want to visualize the cube see this section [Plotting](@ref).

## Cube Types

```@meta
CurrentModule=Main.CABLAB.Cubes
```

```@doc
AbstractCubeData
```

```@doc
CubeMem
```

```@meta
CurrentModule=Main.CABLAB.CubeAPI
```


```@doc
SubCube
```

```@doc
SubCubeV
```

```@meta
CurrentModule=Main.CABLAB.Cubes.TempCubes
```

```@doc
TempCube
```


## Cube Axes
```@autodocs
Modules = [CABLAB.Cubes.Axes]
Private = false
```

# Cube Masks
```@autodocs
Modules = [CABLAB.CubeAPI.Mask]
Private = false
```
