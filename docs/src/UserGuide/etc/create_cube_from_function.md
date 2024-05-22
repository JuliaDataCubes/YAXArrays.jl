# Create cube / YAXArray from function

````@example create_cube
using YAXArrays, Zarr
using Dates
````

## Define function in space and time

````@example create_cube
f(lo, la, t) = (lo + la + Dates.dayofyear(t))
````

Wrap function for mapCube output

````@example create_cube
function g(xout,lo,la,t)
    xout .= f.(lo,la,t)
end
````

Note the applied `.` after `f`, this is because we will slice/broadcasted across time.

## Create Cube's Axes

We wrap the dimensions of every axis into a YAXArray to use them in the mapCube function.

````@ansi create_cube
lon = YAXArray(Dim{:lon}(range(1, 15)))
lat = YAXArray(Dim{:lat}(range(1, 10)))
````

And a time axis

````@ansi create_cube
tspan =  Date("2022-01-01"):Day(1):Date("2022-01-30")
time = YAXArray(Dim{:time}( tspan))
````

## Generate Cube

The following generates a new `cube` using `mapCube` and saving the output directly to disk.

````@example create_cube
gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims(), InDims(), InDims("time")),
    outdims = OutDims("time", overwrite=true,
    path = "my_gen_cube.zarr", backend=:zarr, outtype=Float32),
    ## max_cache=1e9
    )
nothing # hide
````
!!! warning "time axis is first"
    Note that currently the `time` axis in the output cube goes first.

Check that it is working

````@ansi create_cube
gen_cube.data[1,:,:]
````

## Change output order

The following generates a new `cube` using `mapCube` and saving the output directly to disk.

````@example create_cube
gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims("lon"), InDims(), InDims()),
    outdims = OutDims("lon", overwrite=true,
    path = "my_gen_cube.zarr", backend=:zarr, outtype=Float32),
    ## max_cache=1e9
    )
nothing # hide
````

!!! info "slicing dim"
    Note that now the broadcasted dimension is `lon`.

````@ansi create_cube
gen_cube.data[:, :, 1]
````