export InDims, OutDims, MovingWindow
using ..Cubes.Axes: get_descriptor, ByFunction, findAxis, Axes
using ...YAXArrays: YAXDefaults
using DataFrames: DataFrame
using YAXArrayBase: yaxcreate


"""
    MovingWindow(desc, pre, after)

Constructs a `MovingWindow` object to be passed to an `InDims` constructor to define that
the axis in `desc` shall participate in the inner function (i.e. shall be looped over), but inside
the inner function `pre` values before and `after` values after the center value
will be passed as well. 

For example passing `MovingWindow("Time", 2, 0)` will loop over the time axis and 
always pass the current time step plus the 2 previous steps. So in the inner function
the array will have an additional dimension of size 3.    
"""
struct MovingWindow
    desc::Any
    pre::Int
    after::Int
end
Axes.get_descriptor(m::MovingWindow) = MovingWindow(get_descriptor(m.desc), m.pre, m.after)
Axes.findAxis(m::MovingWindow, c) = findAxis(m.desc, c)

wrapWorkArray(::Type{Array}, a, axes) = a
wrapWorkArray(T, a, axes) =
    yaxcreate(T, a, map(axname, axes), map(i -> i.values, axes), nothing)

abstract type ProcFilter end
struct AllMissing <: ProcFilter end
struct NValid <: ProcFilter
    n::Int
end
struct AnyMissing <: ProcFilter end
struct AnyOcean <: ProcFilter end
struct NoFilter <: ProcFilter end
struct StdZero <: ProcFilter end
struct UserFilter{F} <: ProcFilter
    f::F
end

checkskip(::NoFilter, x) = false
checkskip(::AllMissing, x::AbstractArray) = all(ismissing, x)
checkskip(::AllMissing, df::DataFrame) =
    any(map(i -> all(ismissing, getindex(df, i)), names(df)))
checkskip(::AnyMissing, x::AbstractArray) = any(ismissing, x)
checkskip(::AnyMissing, df::DataFrame) =
    any(map(i -> any(ismissing, getindex(df, i)), names(df)))
checkskip(nv::NValid, x::AbstractArray) = count(!ismissing, x) <= nv.n
checkskip(uf::UserFilter, x) = uf.f(x)
checkskip(::StdZero, x) = all(i -> i == x[1], x)
docheck(pf::ProcFilter, x)::Bool = checkskip(pf, x)
docheck(pf::Tuple, x) = reduce(|, map(i -> docheck(i, x), pf))

getprocfilter(f::Function) = (UserFilter(f),)
getprocfilter(pf::ProcFilter) = (pf,)
getprocfilter(pf::NTuple{N,<:ProcFilter}) where {N} = pf

"""
    InDims(axisdesc...;...)

Creates a description of an Input Data Cube for cube operations. Takes a single
  or multiple axis descriptions as first arguments. Alternatively a MovingWindow(@ref) struct can be passed to include
  neighbour slices of one or more axes in the computation. 
  Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

### Keyword arguments

* `artype` how shall the array be represented in the inner function. Defaults to `Array`, alternatives are `DataFrame` or `AsAxisArray`
* `filter` define some filter to skip the computation, e.g. when all values are missing. Defaults to
    `AllMissing()`, possible values are `AnyMissing()`, `AnyOcean()`, `StdZero()`, `NValid(n)`
    (for at least n non-missing elements). It is also possible to provide a custom one-argument function
    that takes the array and returns `true` if the compuation shall be skipped and `false` otherwise.
* `window_oob_value` if one of the input dimensions is a MowingWindow, this value will be used to fill out-of-bounds areas
"""
mutable struct InDims
    axisdesc::Tuple
    artype::Any
    procfilter::Tuple
    window_oob_value::Any
end
function InDims(
    axisdesc::Union{String,CubeAxis,Symbol,MovingWindow}...;
    artype = Array,
    filter = AllMissing(),
    window_oob_value = missing,
)
    descs = get_descriptor.(axisdesc)
    any(i -> isa(i, ByFunction), descs) &&
        error("Input cubes can not be specified through a function")
    InDims(descs, artype, getprocfilter(filter), window_oob_value)
end


struct OutDims
    axisdesc::Any
    backend::Symbol
    backendargs::Any
    update::Bool
    artype::Any
    chunksize::Any
    outtype::Union{Int,DataType}
end
"""
    OutDims(axisdesc;...)

Creates a description of an Output Data Cube for cube operations. Takes a single
  or a Vector/Tuple of axes as first argument. Axes can be specified by their
  name (String), through an Axis type, or by passing a concrete axis.

- `axisdesc`: List of input axis names
- `backend` : specifies the dataset backend to write data to, must be either :auto or a key in `YAXArrayBase.backendlist`
- `update` : specifies wether the function operates inplace or if an output is returned
- `artype` : specifies the Array type inside the inner function that is mapped over
- `chunksize`: A Dict specifying the chunksizes for the output dimensions of the cube, or `:input` to copy chunksizes from input cube axes or `:max` to not chunk the inner dimensions
- `outtype`: force the output type to a specific type, defaults to `Any` which means that the element type of the first input cube is used
"""
function OutDims(
    axisdesc...;
    backend = :auto,
    update = false,
    artype = Array,
    chunksize = YAXDefaults.chunksize[],
    outtype = 1,
    backendargs...,
)
    descs = get_descriptor.(axisdesc)
    OutDims(descs, backend, backendargs, update, artype, chunksize, outtype)
end

registerDATFunction(a...; kwargs...) =
    @warn("Registration does not exist anymore, ignoring....")
