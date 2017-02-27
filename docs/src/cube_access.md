# Accessing the Data Cube

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
time=(Date("2001-01-01"),Date("2001-12-31"))
cubedata = getCubeData(c,longitude=(30,31),latitude=(50,51),time=time,variable=var)
```

This returns a view into the Data Cube, on which further calculations can be applied.
All keyword arguments default to the full range, so calling `getCubeData` without
keyword arguments will return a view into the whole data cube.

```@docs
CABLAB.CubeAPI.getCubeData
```


No data is read yet. Here you can start to do some calculations on your sub-cube, see either
[Analysis](@ref) for a list of methods provided by this framework or
[Applying custom functions](@ref) to apply your own functions on the cube. If you just
want to visualize the cube see this section [Plotting](@ref).

## Extracting a list of lon/lat coordinates from a data cube

There are situations in which only a certain list of longitude/latitude pairs is
needed for the analysis. One can extract such a list by first creating a cube view
containing all the needed variables and then apply the `extractLonLats` function.

```@docs
CABLAB.Proc.CubeIO.extractLonLats
```

Here is an example how to apply the function:

```@example 1
cubedata = getCubeData(c,longitude=(30,31),latitude=(50,51),time=time,variable=var)
ll       = [30.1 50.2;
            30.5 51.1;
            30.7 51.1] #Lon/Lats to be extracted
cubenew  = extractLonLats(cubedata,ll)
```

## Cube Types

In CABLAB, you will

```@docs
CABLAB.Cubes.AbstractCubeData
```

```@docs
CABLAB.Cubes.CubeMem
```


```@docs
CABLAB.CubeAPI.SubCube
```

```@docs
CABLAB.CubeAPI.SubCubeV
```


```@docs
CABLAB.Cubes.TempCubes.TempCube
```


## Cube Axes

Axes are an essential part of each Cube in CABLAB. Every dimension that a cube has is associated
with an axis that stores the values of the dimension. For example, a `LatitudeAxis` will contains a
field `values` representing the chosen latitudes. Similarly, a `VariableAxis` will contain a list of
Variable names. Axes types are divided in categorical axes and axes represented by ranges. All of them
are subtypes of the abstract type `CubeAxis`.

```@docs
CABLAB.Cubes.Axes.CubeAxis
```

```@docs
CABLAB.Cubes.Axes.CategoricalAxis
```

```@docs
CABLAB.Cubes.Axes.RangeAxis
```

## Cube Masks

Every data cube type in CABLAB contains has a representation for the mask, which
has the primary purpose of describing missing values and the reason for missingness.
CABLAB masks are represented as `UInt8`-arrays, where each value can be one of the following:

* `VALID` a regular data entry
* `MISSING` classical missing value
* `OCEAN` masked out by the land-sea mask
* `OUTOFPERIOD` current time step is not inside the measurement period
* `FILLED` does not count as missing, but still denotes that the value is gap filled and not measured

These names can be imported by `using CABLAB.Mask`. The user can decide if he wants to use
the masks in his analyses or rather wants to refer to a different representation with
`NullableArray`s or just representing missings with `NaN`s. See [registerDATFunction](@ref) for details.

## Opening Remote Data Cubes

If you just want to try the CABLAB data cube and don't have access to the full data set, you can open a remote cube through
a THREDDS server. All you need is a working internet connection to do this:

```@docs
RemoteCube
```

This will open the remote cube and calling `getCubeData` will return a cube view that you can process.

**Important** In order to avoid unnecessary traffic, be nice to our servers.
Please use this only for testing the cube software for very limited amount of data (reading maps at single time steps)
or time series in lon-lat boxes of size 1degx1deg.

## Point-wise access

```@docs
sampleLandPoints
```

## List of known regions

```@docs
CABLAB.CubeAPI.known_regions
```
