import Base: /
using ..YAXTools: PickAxisArray
struct YAXSlice{T,N,P}
    c::P
    sliceaxes::Any
    otheraxes::Any
end
function YAXSlice(p, dims)
    N = ndims(p)
    ax = caxes(p)
    isliceax = (findAxis.(dims, Ref(ax))...,)
    any(isnothing, isliceax) && error("Axis not in cube")
    iotherax = (filter(i -> !in(i, isliceax), 1:N)...,)
    YAXSlice{Array{eltype(p),length(dims)},N - length(dims),typeof(p)}(
        p,
        (isliceax, getindex.(Ref(ax), isliceax)),
        (iotherax, getindex.(Ref(ax), iotherax)),
    )
end
/(c::YAXArray, s::Union{String,Symbol}) = YAXSlice(c, (s,))
/(c::YAXArray, s) = YAXSlice(c, s)

dimvals(x::YAXSlice, i) = x.c.axes[x.otheraxes[1][i]].values

function dimname(x::YAXSlice, i)
    axsym(x.otheraxes[2][i])
end

getattributes(x::YAXSlice) = x.c.properties

iscontdim(x::YAXSlice, i) = isa(x.c.axes[x.otheraxes[1][i]], RangeAxis)

function getdata(x::YAXSlice)
    m = fill!(Array{Union{Colon,Bool}}(undef, ndims(x.c)), true)
    m[collect(x.sliceaxes[1])] .= Colon()
    PickAxisArray(x.c.data, m)
end

getCubeDes(s::YAXSlice) =
    string(join(axname.(s.sliceaxes[2]), " x "), " slices over an ", getCubeDes(s.c))
cubesize(s::YAXSlice) = cubesize(s.c)
Base.ndims(::YAXSlice{<:Any,N}) where {N} = N

Base.show(io::IO, s::YAXSlice) = YAXArrays.Cubes.show_yax(io, s)
