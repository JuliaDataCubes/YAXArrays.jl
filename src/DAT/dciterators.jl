import YAXArrays.DAT: DATConfig
import YAXArrays.YAXTools: PickAxisArray
using YAXArrays.Cubes.Axes: axcopy
using DiskArrays: GridChunks, AbstractDiskArray
using Tables: Tables, Schema, AbstractColumns

struct CubeIterator{R,LAX,S<:Schema} <: AbstractVector{Any}
    dc::DATConfig
    r::R
    loopaxes::LAX
    schema::S
end
Tables.schema(t::CubeIterator) = t.schema
Base.length(ci::CubeIterator) = length(ci.r)
Base.size(ci::CubeIterator) = (length(ci.r),)
Base.eltype(ci::Type{<:CubeIterator{<:R,<:LAX}}) where {R,LAX} = YAXTableChunk{ci, LAX, eltype(R)}
Base.eltype(ci::CubeIterator)  = eltype(typeof(ci))
function Base.getindex(t::CubeIterator, i::Int)
    rnow = t.r[i]
    laxsmall = map(t.loopaxes, rnow) do ax,ir
        axcopy(ax,ax.values[ir])
    end
    cols = Union{Nothing,YAXColumn}[nothing for i in t.schema.names]
    return YAXTableChunk(t,laxsmall,rnow,cols)
end
function Base.show(io::IO, ci::CubeIterator)
    print(
        io,
        "Datacube iterator with ",
        length(ci.r),
        " subtables with fields: ",
        ci.schema.names,
    )
end
function Base.show(io::IO, ::MIME"text/plain", X::CubeIterator)
  show(io,X)    
end


"""
    YAXColumn

A struct representing a single column of a YAXArray partitioned Table
"""
struct YAXColumn{T,A,IT} <: AbstractVector{T}
    inarBC::A
    inds::IT
end
Base.getindex(a::YAXColumn,i) = a.inarBC[a.inds[i]]
Base.length(a::YAXColumn) = length(a.inds)
Base.size(a::YAXColumn) = (length(a.inds),)


struct YAXTableChunk{CI<:CubeIterator, LAX, IC} <: AbstractColumns
    ci::CI
    loopaxes::LAX
    ichunk::IC
    cols::Vector{Union{Nothing,YAXColumn}}
end
function Tables.getcolumn(t::YAXTableChunk, i::Int) 
    cols = getfield(t,:cols)
    if cols[i] === nothing
        cols[i] = YAXColumn(t,i)
    end
    cols[i]
end
function Tables.getcolumn(t::YAXTableChunk, s::Symbol)
    n = Tables.schema(t).names
    i = findfirst(==(s), n)
    if i === nothing
        error("Could not find $s in table with columns $n")
    end
    Tables.getcolumn(t,i)
end
Tables.columnnames(t::YAXTableChunk) = getfield(t,:ci).schema.names
Tables.schema(t::YAXTableChunk) = getfield(t,:ci).schema
function Base.show(io::IO, X::YAXTableChunk)
    println(io,"Table chunk with schema:")
    print(io,getfield(X,:ci).schema)
end
Base.show(io::IO, ::MIME"text/plain", X::YAXTableChunk) = show(io,X)

function YAXColumn(t::YAXTableChunk,ivar)
    ci = getfield(t,:ci)
    rnow = getfield(t,:ichunk)
    if ivar > length(ci.dc.incubes)
        iax = ivar-length(ci.dc.incubes)
        axvals = getfield(t,:loopaxes)[iax].values
        allax = map(_->false, getfield(t,:loopaxes))
        allax = Base.setindex(allax, true, iax)
        inarbc = PickAxisArray(axvals, allax)
        inds = CartesianIndices(Base.OneTo.(length.(rnow)))
        return YAXColumn{eltype(inarbc),typeof(inarbc), typeof(inds)}(inarbc, inds)
    else
        ic = ci.dc.incubes[ivar]
        buf = allocatecachebuf(ic, ci.dc.loopcachesize)
        updatear(:read, rnow, ic.cube, geticolon(ic), ic.loopinds, buf)
        allax = ntuple(_->false, ndims(ic.cube))
        for il in ic.loopinds
            allax = Base.setindex(allax,true,il)
        end
        for il in ic.icolon
            allax = Base.setindex(allax,Colon(),il)
        end
        inarbc = if ic.colonperm === nothing
            pa = PickAxisArray(buf, allax)
        else
            pa = PickAxisArray(buf, allax, ic.colonperm)
        end
        inds = CartesianIndices(Base.OneTo.(length.(rnow)))
        return YAXColumn{eltype(inarbc),typeof(inarbc), typeof(inds)}(inarbc, inds)
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
"""
function CubeTable(; expandaxes = (), cubes...)
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
    foreach(1:length(axnames)) do i
        otheraxes = axnames[[1:i-1;i+1:length(axnames)]]
        if !isempty(otheraxes) && isempty(intersect(axnames[i], union(otheraxes...)))
            @warn "Input cube $i with axes $(axnames[i]) does not share any axis with other cubes from the iterator, please check the axis names"
        end
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
    r = GridChunks(
        getloopchunks(configiter)...
    )
    ci = CubeIterator(configiter, r, varnames = varnames)
end




function CubeIterator(
    dc,
    r;
    varnames::Tuple = ntuple(i -> Symbol("x$i"), length(dc.incubes)),
)
    loopaxes = (dc.LoopAxes...,)
    length(varnames) == length(dc.incubes) ||
        error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    et = map(dc.incubes) do ic
        eltype(ic.cube)
    end
    et = (et..., map(i->eltype(i.values), loopaxes)...)
    axnames = axsym.(loopaxes)
    colnames = (map(Symbol, varnames)..., axnames...)
    CubeIterator(
        dc,
        r,
        loopaxes,
        Tables.Schema(colnames,et)
    )
end

import Tables
