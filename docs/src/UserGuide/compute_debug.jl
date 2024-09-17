using YAXArrays, Dates
using Random

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-05")),
    Dim{:lon}(range(1, 4, length=4)),
    Dim{:lat}(range(1, 3, length=3)),
    Dim{:variables}(["a", "b"])
)

Random.seed!(123)
data = rand(1:5, 5, 4, 3, 2)

properties = Dict("description" => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)

properties_2d = Dict("description" => "2d dimensional test cube")
yax_2d = YAXArray(axlist[2:end], rand(-1:1, 4, 3, 2), properties_2d)

f1(xin) = xin + 1
f2(xin) = xin + 2
function one_to_many(xout_one, xout_two, xout_flat, xin_one)
    xout_one .= f1.(xin_one)
    xout_two .= f2.(xin_one)
    xout_flat .= sum(xin_one) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end

indims_one   = InDims("Time")
# outputs dimension
outdims_one = OutDims("Time", name="plus_one")
outdims_two = OutDims("Time", name="plus_two", units ="double")
outdims_flat = OutDims(; name="flat") # space
  
ds = mapCube(one_to_many, yax_test,
    indims = indims_one,
    outdims = (outdims_one, outdims_two, outdims_flat));

# many to many.  mix input dimensions

f2mix(xin_xyt, xin_xy) = xin_xyt - xin_xy

function many_to_many(xout_one, xout_two, xout_flat, xin_one, xin_two, xin_drei)
    xout_one .= f1.(xin_one)
    xout_two .= f2mix.(xin_one, xin_two)
    xout_flat .= sum(xin_drei) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end

indims_one   = InDims("Time")
indims_2d   = InDims() # it matches only to the other 2 dimensions and uses the same values for each time step

outdims_one = OutDims("Time", name="plus_one")
outdims_two = OutDims("Time", name="plus_two", units ="double")
outdims_flat = OutDims(; name="flat") # space
 
ds = mapCube(many_to_many, (yax_test, yax_2d, yax_test),
    indims = (indims_one, indims_2d, indims_one),
    outdims = (outdims_one, outdims_two, outdims_flat));


properties_2dz = Dict("description" => "2d-z dimensional test cube")

axlist = (
    Dim{:lon}(range(1, 4, length=4)),
    Dim{:lat}(range(1, 3, length=3)),
    Dim{:depth}(range(1, 2, length=2)),
    Dim{:variables}(["a", "b"])
)

yax_2dz = YAXArray(axlist, rand(-2:2, 4, 3, 2, 2), properties_2dz)

function f2mix_depth(xin_xyt, xin_xyz)
    @show xin_xyz
    return xin_xyt + sum(abs.(xin_xyz))
end

function many_to_many_depth(xout_one, xout_two, xout_flat, xin_one, xin_two)
    xout_one .= f1.(xin_one)
    xout_two .= f2mix_depth.(xin_one, xin_two)
    xout_flat .= sum(abs.(xin_two)) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end

indims_one = InDims("Time")
indims_2d   = InDims() # it matches only to the other 2 dimensions and uses the same values for each time step
outdims_one = OutDims("Time")
outdims_two = OutDims("Time")
outdims_flat = OutDims() # space

ds = mapCube(many_to_many_depth, (yax_test, yax_2dz),
    indims = (indims_one, indims_2d),
    outdims = (outdims_one, outdims_two, outdims_flat))


function many_depth(xout_two, xin_one, xin_two)
    xout_two .= f2mix_depth.(xin_one, xin_two)
    return nothing
end
function f2mix_depth(xin_xyt, xin_xyz)
    s = sum(abs.(xin_xyz))
    # @show s # is not doing what I think is doing!
    # @show xin_xyz
    return xin_xyt + s
end

ds = mapCube(many_depth, (yax_test[Variable= At("a")], yax_2dz[Variable= At("a")]),
    indims = (InDims("Time"), InDims()),
    outdims = OutDims("Time"))
    
yax_s = sum(yax_2dz[Variable= At("a")], dims=:depth)
yax_s = dropdims(yax_s, dims=:depth)

# use case, things should operate at the pixel level, (lon, lat) and extract the corresponding values there.

axlist = (
    Dim{:lon}(1:4),
    Dim{:lat}(1:3),
    Dim{:depth}(1:7),
)

yax_2d = YAXArray(axlist, rand(-3:0, 4, 3, 7))

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-05")),
    Dim{:lon}(1:4),
    Dim{:lat}(1:3),
)

Random.seed!(123)
data = rand(3:5, 5, 4, 3)

properties = Dict("description" => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)

function mix_time_depth(xin_xyt, xin_xyz)
    s = sum(abs.(xin_xyz))
    @show s # ? is doing what I think is doing!
    @show xin_xyz
    return xin_xyt.^2 .+ s
end

function time_depth(xout, xin_one, xin_two)
    xout .= mix_time_depth(xin_one, xin_two) # ? note also here, no dot anymore!
    return nothing
end

ds = mapCube(time_depth, (yax_test, yax_2dz),
    indims = (InDims("Time"), InDims("depth")), 
    # ? it shouldn't be better to say "lon", "lat". Logic? well, you specify an anchor dimension and then map over the others.
    outdims = OutDims("Time"))