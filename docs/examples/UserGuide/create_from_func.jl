using YAXArrays, Zarr
using Dates

# Define function in space and time

f(lo, la, t) = (lo + la + Dates.dayofyear(t))

# ## Wrap function for mapCube output

function g(xout,lo,la,t)
    xout .= f.(lo,la,t)
end

# Note the applied `.` after `f`, this is because we will slice across time,
# hence the application is broadcasted along this dimension.

# ## Create Cube's Axes

# We do this via `RangeAxis` for every dimension
lon = YAXArray(RangeAxis("lon", range(1, 15)))
lat = YAXArray(RangeAxis("lat", range(1, 10)))
# And a time Cube's Axes
tspan =  Date("2022-01-01"):Day(1):Date("2022-01-30")
time = YAXArray(RangeAxis("time", tspan))


# ## Generate Cube from function
# The following generates a new `cube` using `mapCube` and saving the output directly to disk.

gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims(), InDims(), InDims("time")),
    outdims = OutDims("time", overwrite=true,
    path = "my_gen_cube.zarr", backend=:zarr, outtype=Float32),
    #max_cache=1e9
    )

# !!! warning "time axis is first"
#     Note that currently the `time` axis in the output cube goes first.

# Check that it is working

gen_cube.data[1,:,:]

# ## Generate Cube: change output order

# The following generates a new `cube` using `mapCube` and saving the output directly to disk.

gen_cube = mapCube(g, (lon, lat, time);
    indims = (InDims("lon"), InDims(), InDims()),
    outdims = OutDims("lon", overwrite=true,
    path = "my_gen_cube.zarr", backend=:zarr, outtype=Float32),
    #max_cache=1e9
    )

# !!! info "slicing dim"
#     Note that now the broadcasted dimension is `lon`.

gen_cube.data[:, :, 1]