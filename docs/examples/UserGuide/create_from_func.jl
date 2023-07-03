using YAXArrays, Zarr
using Dates

# Define function in space and time

f(lo, la, t) = (lo + la + Dates.dayofyear(t))

# ## Wrap function for mapCube output

function g(xout, lo, la, t)
    xout .= f.(lo, la, t)
end

# Note the applied `.` after `f`, this is because we will slice across time,
# hence the application is broadcasted along this dimension.

# ## Create Cube's Axes

# We do this via `RangeAxis` for every dimension
lon = YAXArray(RangeAxis("lon", range(1, 15)))
lat = YAXArray(RangeAxis("lat", range(1, 10)))
# And a time Cube's Axes
tspan = Date("2022-01-01"):Day(1):Date("2022-01-30")
time = YAXArray(RangeAxis("time", tspan))


# ## Generate Cube from function
# The following generates a new `cube` using `mapCube` and saving the output directly to disk.

gen_cube = mapCube(g, (lon, lat, time);
    indims=(InDims(), InDims(), InDims("time")),
    outdims=OutDims("time", overwrite=true,
        path="my_gen_cube.zarr", backend=:zarr, outtype=Float32)
    #max_cache=1e9
)

# !!! warning "time axis is first"
#     Note that currently the `time` axis in the output cube goes first.

# Check that it is working

gen_cube.data[1, :, :]

# ## Generate Cube: change output order

# The following generates a new `cube` using `mapCube` and saving the output directly to disk.

gen_cube = mapCube(g, (lon, lat, time);
    indims=(InDims("lon"), InDims(), InDims()),
    outdims=OutDims("lon", overwrite=true,
        path="my_gen_cube.zarr", backend=:zarr, outtype=Float32)
    #max_cache=1e9
)

# !!! info "slicing dim"
#     Note that now the broadcasted dimension is `lon`.

gen_cube.data[:, :, 1]

# ## Generate Cube: change output order

# The following generates a new `cube` using `mapCube` and saving the output directly to disk.

gen_cube = mapCube(g, (lon, lat, time);
    indims=(InDims("lon"), InDims(), InDims()),
    outdims=OutDims("lon", overwrite=true,
        path="my_gen_cube.zarr", backend=:zarr, outtype=Float32)
    #max_cache=1e9
)

# !!! info "slicing dim"
#     Note that now the broadcasted dimension is `lon`.

gen_cube.data[:, :, 1]

# ## Generate Cube: Modify dimensions

# One can also change the dimensions of a YAXArray.
# For example, the location of `gen_cube` can be also expressed as a region or area of interest.
# The following example transforms the raster data cube with two spatial dimensions,
# i.e., longitude and latitude, into a [vector data cube](https://r-spatial.org/r/2022/09/12/vdc.html) with just one spatial dimension i.e. the region (e.g. district or country).

# First, create a function `geo_region` to calculate the region for given geographical coordinates. In practice, one might use a spatial join of points to polygons here.

function get_region(lon, lat)
    1 <= lon < 10 && 1 <= lat < 5 && return "A"
    1 <= lon < 10 && 5 <= lat < 10 && return "B"
    10 <= lon < 15 && 1 <= lat < 5 && return "C"
    return "D"
end

# Next, create a function `transform_cube` that will aggregate the values for any given time step.
# `xin` is the raster data at one time step that is a Matrix with values `xin[lon, lat]`
# `xout` is the vector data at one time step that is a Vector with values `xout[region]`

function transform_cube(xout, xin, regions, points_to_regions_matrix)
    result = Vector{eltype(xin)}(undef, length(xout))
    for (i, region) in enumerate(regions)
        region_points = findall(isequal(region), points_to_regions_matrix)
        result[i] = sum(xin[region_points]) # Aggregate all points of this region
    end
    xout .= result
end

regions = ["A", "B", "C", "D"]
points_to_regions_matrix = [get_region(t...) for t = Iterators.product(gen_cube.lon, gen_cube.lat)]

vector_cube = mapCube(
    transform_cube,
    gen_cube,
    regions,
    points_to_regions_matrix,
    indims=InDims("lon", "lat"),
    outdims=OutDims(CategoricalAxis("region", regions))
)