include("SentinelMissings.jl")
import .SentinelMissings
import YAXArrays.DAT: DATConfig
import YAXArrays.YAXTools: PickAxisArray

struct CubeIterator{R,ART,ARTBC,LAX,ILAX,S}
    dc::DATConfig
    r::R
    inars::ART
    inarsBC::ARTBC
    loopaxes::LAX
end
Base.IteratorSize(::Type{<:CubeIterator}) = Base.HasLength()
Base.IteratorEltype(::Type{<:CubeIterator}) = Base.HasEltype()
Base.eltype(i::Type{<:CubeIterator{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = F

tuplelen(::Type{<:NTuple{N,<:Any}}) where {N} = N

lift64(::Type{Float32}) = Float64
lift64(::Type{Int32}) = Int64
lift64(T) = T

defaultval(t::Type{<:AbstractFloat}) = convert(t, NaN)
defaultval(t::Type{<:Signed}) = typemin(t) + 1
defaultval(t::Type{<:Unsigned}) = typemax(t) - 1

function CubeIterator(
    dc,
    r;
    varnames::Tuple = ntuple(i -> Symbol("x$i"), length(dc.incubes)),
    include_loopvars = (),
)
    loopaxes = ntuple(i -> dc.LoopAxes[i], length(dc.LoopAxes))
    inars, _ = getCubeCache(dc)
    length(varnames) == length(dc.incubes) ||
        error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    inarsbc = map(dc.incubes, inars) do ic, cache
        allax = getindsall(geticolon(ic), ic.loopinds, i -> true)
        if ic.colonperm === nothing
            pa = PickAxisArray(cache, allax)
        else
            pa = PickAxisArray(cache, allax, ic.colonperm)
        end
    end
    et = map(inarsbc) do ibc
        ti = eltype(ibc)
        if ti <: AbstractArray
            ti
        else
            ti = Base.nonmissingtype(ti)
            SentinelMissings.SentinelMissing{ti,defaultval(ti)}
        end
    end
    if include_loopvars == true
        include_loopvars = map(axname, (loopaxes...,))
    end
    if isa(include_loopvars, Tuple) && !isempty(include_loopvars)
        ilax = map(i -> findAxis(i, collect(loopaxes)), include_loopvars)
        any(isequal(nothing), ilax) && error("Axis not found in cubes")
        et = (et..., map(i -> eltype(loopaxes[i]), ilax)...)
    else
        ilax = ()
    end

    elt = NamedTuple{
        (map(Symbol, varnames)..., map(Symbol, include_loopvars)...),
        Tuple{et...},
    }
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),ilax,elt}(
        dc,
        r,
        inars,
        inarsbc,
        loopaxes,
    )
end
iternames(::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,E}) where {E} = E
tuplenames(t::Type{<:NamedTuple{N}}) where {N} = string.(N)
function Base.show(io::IO, ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,E}) where {E}
    print(
        io,
        "Datacube iterator with ",
        length(ci),
        " elements with fields: ",
        tuplenames(E),
    )
end
Base.length(ci::CubeIterator) = prod(length.(ci.loopaxes))
function Base.iterate(ci::CubeIterator)
    rnow, blockstate = iterate(ci.r)
    updatears(ci.dc.incubes, rnow, :read, ci.inars)
    innerinds = CartesianIndices(length.(rnow))
    indnow, innerstate = iterate(innerinds)
    offs = map(i -> first(i) - 1, rnow)
    getrow(ci, ci.inarsBC, indnow, offs),
    (rnow = rnow, blockstate = blockstate, innerinds = innerinds, innerstate = innerstate)
end
function Base.iterate(ci::CubeIterator, s)
    t1 = iterate(s.innerinds, s.innerstate)
    N = tuplelen(eltype(ci.r))
    if t1 === nothing
        t2 = iterate(ci.r, s.blockstate)
        if t2 === nothing
            return nothing
        else
            rnow = t2[1]
            blockstate = t2[2]
            updatears(ci.dc.incubes, rnow, :read, ci.inars)
            innerinds = CartesianIndices(length.(rnow))
            indnow, innerstate = iterate(innerinds)

        end
    else
        rnow, blockstate = s.rnow, s.blockstate
        innerinds = s.innerinds
        indnow, innerstate = iterate(innerinds, s.innerstate)
    end
    offs = map(i -> first(i) - 1, rnow)
    getrow(ci, ci.inarsBC, indnow, offs),
    (
        rnow = rnow::NTuple{N,UnitRange{Int64}},
        blockstate = blockstate::Int64,
        innerinds = innerinds::CartesianIndices{N,NTuple{N,Base.OneTo{Int64}}},
        innerstate = innerstate::CartesianIndex{N},
    )
end
abstract type CubeRow end
abstract type CubeRowAx <: CubeRow end

function getrow(
    ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,ILAX,S},
    inarsBC,
    indnow,
    offs,
) where {ILAX,S}
    axvalsall = map((ax, i, o) -> ax.values[i+o], ci.loopaxes, indnow.I, offs)
    axvals = map(i -> axvalsall[i], ILAX)
    cvals = map(i -> i[indnow], inarsBC)
    S((cvals..., axvals...))
end
function getrow(
    ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,(),S},
    inarsBC,
    indnow,
    offs,
) where {S}
    cvals = map(i -> i[indnow], inarsBC)
    S(cvals)
end

function Base.show(io::IO, s::CubeRow)
    print(io, "Cube Row: ")
    for n in propertynames(s)
        print(io, string(n), "=", getproperty(s, n), " ")
    end
end
function Base.show(io::IO, s::CubeRowAx)
    print(io, "Cube Row: ")
    for n in propertynames(s)
        print(io, string(n), "=", getproperty(s, n), " ")
    end
end
function Base.show(io::IO, s::Type{<:CubeRow})
    foreach(fieldnames(s)) do fn
        print(io, fn, "::", fieldtype(s, fn), ", ")
    end
end
function Base.iterate(s::CubeRow, state = 1)
    allnames = propertynames(s)
    if state <= length(allnames)
        (getproperty(s, allnames[state]), state + 1)
    else
        nothing
    end
end


export CubeTable
"""
    CubeTable()

Function to turn a DataCube object into an iterable table. Takes a list of as arguments,
specified as a `name=cube` expression. For example
`CubeTable(data=cube1,country=cube2)` would generate a Table with the entries `data` and `country`,
where `data` contains the values of `cube1` and `country` the values of `cube2`. The cubes
are matched and broadcasted along their axes like in `mapCube`.

In addition, one can specify
`include_axes=(ax1,ax2...)` when one wants to include the values of certain axes in the table. For example
the command `(CubeTable(tair=cube1 axes=("lon","lat","time"))` would produce an iterator over a data structure
with entries `tair`, `lon`, `lat` and `time`.
"""
function CubeTable(; include_axes = (), expandaxes = (), cubes...)
    c = (map((k, v) -> v, keys(cubes), values(cubes))...,)
    all(i -> isa(i, Union{YAXArray,AbstractArray}), c) ||
        throw(ArgumentError("All inputs must be DataCubes"))
    varnames = map(string, keys(cubes))
    expandaxes = isa(expandaxes, Tuple) ? expandaxes : (expandaxes,)
    inaxnames = Set{String}()
    indims = if isempty(expandaxes)
        map(i -> InDims(), c)
    else
        map(c) do i
            axn = filter(collect(expandaxes)) do ax
                findAxis(ax, i) !== nothing
            end
            foreach(j -> push!(inaxnames, axname(getAxis(j, i))), axn)
            InDims(axn...)
        end
    end
    axnames = map(i -> axname.(caxes(i)), c)
    if isempty(intersect(axnames...))
        @warn "Input cubes to the table do not share a common axis, please check the axis names"
    end
    allvars = union(axnames...)
    allnums = collect(1:length(allvars))

    configiter =
        mapCube(identity, c, debug = true, indims = indims, outdims = (), ispar = false)
    # if inax !== nothing
    #   linax = length(inax)
    #   foreach(configiter.incubes) do ic1
    #     if !isempty(ic1.axesSmall)
    #       empty!(ic1.axesSmall)
    #       map!(i->i+1,ic1.loopinds,ic1.loopinds)
    #       pushfirst!(ic1.loopinds,1)
    #     else
    #       map!(i->i+1,ic1.loopinds,ic1.loopinds)
    #     end
    #   end
    # end
    r = collect(
        distributeLoopRanges(
            (configiter.loopcachesize...,),
            (map(length, configiter.LoopAxes)...,),
            getchunkoffsets(configiter),
        ),
    )
    ci = CubeIterator(configiter, r, include_loopvars = include_axes, varnames = varnames)
end

import Tables
Tables.istable(::Type{<:CubeIterator}) = true
Tables.rowaccess(::Type{<:CubeIterator}) = true
Tables.rows(x::CubeIterator) = x
Tables.schema(x::CubeIterator) = Tables.schema(typeof(x))
Tables.schema(x::Type{<:CubeIterator}) = Tables.Schema(
    fieldnames(eltype(x)),
    map(s -> fieldtype(eltype(x), s), fieldnames(eltype(x))),
)

Tables.istable(::Type{<:YAXArray}) = true
Tables.rowaccess(::Type{<:YAXArray}) = true
Tables.rows(x::YAXArray) = CubeTable(value = x, include_axes = true)
Tables.schema(x::YAXArray) = Tables.schema(Tables.rows(x))
