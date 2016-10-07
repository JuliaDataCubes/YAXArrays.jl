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


## Cube Types

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
