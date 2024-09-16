using YAXArrays, Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-10")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:variables}(["a", "b"])
)
data = 2*ones(10, 10, 15, 2)
properties = Dict(:description => "multi dimensional test cube")
yax_test = YAXArray(axlist, data, properties)

function one_to_many(xout_sqrt, xout_quad, xout_flat, xin_one)
    xout_sqrt .= xin_one .^2
    xout_quad .= xin_one .^4
    xout_flat .= sum(xin_one) # this will reduce the time dimension if we set outdims = OutDims()
    return nothing
end

indims_one   = InDims("Time")
# outputs dimension
outdims_sqrt = OutDims("Time")
outdims_quad = OutDims("Time", name="quads", units ="double")
outdims_flat = OutDims(; name="flat") # space
  
ds = mapCube(one_to_many, yax_test,
    indims = indims_one,
    outdims = (outdims_sqrt, outdims_quad, outdims_flat));
