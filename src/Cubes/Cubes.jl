"""
The functions provided by YAXArrays are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
using DiskArrays: DiskArrays, eachchunk, approx_chunksize, max_chunksize, grid_offset, GridChunks
using Distributed: myid
using Dates: TimeType, Date
using IntervalSets: Interval, (..)
using Base.Iterators: take, drop
using ..YAXArrays: workdir, YAXDefaults, findAxis, getAxis
using YAXArrayBase: YAXArrayBase, iscompressed, dimnames, iscontdimval
import YAXArrayBase: getattributes, iscontdim, dimnames, dimvals, getdata
using DiskArrayTools: CFDiskArray
using DocStringExtensions
using Tables: istable, schema, columns
using DimensionalData: DimensionalData as DD, AbstractDimArray, NoName
import DimensionalData: name

export concatenatecubes, caxes, subsetcube, readcubedata, renameaxis!, YAXArray, setchunks

"""
This function calculates a subset of a cube's data
"""
function subsetcube end

"Returns the axes of a Cube"
function caxes end

# TODO: Give Axes an own module in YAXArrays
#=
include("Axes.jl")
using .Axes:
    CubeAxis,
    RangeAxis,
    CategoricalAxis,
    findAxis,
    getAxis,
    axVal2Index,
    axname,
    axsym,
    axVal2Index_lb,
    axVal2Index_ub,
    renameaxis,
    axcopy

"""
The `Axes` module handles the Axes of a data cube. 
It provides the following exports:

$(EXPORTS)
"""
Axes
=#
"""
    mutable struct CleanMe

Struct which describes data paths and their persistency. Non-persistend paths/files are removed at finalize step
"""
mutable struct CleanMe
    path::String
    persist::Bool
    function CleanMe(path::String, persist::Bool)
        c = new(path, persist)
        finalizer(clean, c)
        return c
    end
end
"""
    clean(c::CleanMe)

finalizer function for CleanMe struct. The main process removes all directories/files which are not persistent.
"""
function clean(c::CleanMe)
    if !c.persist && myid() == 1
        if !isdir(c.path) && !isfile(c.path)
            #@warn "Cube directory $(c.path) does not exist. Can not clean"
        else
            rm(c.path, recursive=true)
        end
    end
end

"""
    YAXArray{T,N}

An array labelled with named axes that have values associated with them.
It can wrap normal arrays or, more typically DiskArrays.

### Fields

$(FIELDS)
"""
struct YAXArray{T,N,A<:AbstractArray{T,N}, D} <: AbstractDimArray{T,N,D,A} 
    "`Tuple` of Dimensions containing the Axes of the Cube"
    axes::D
    "length(axes)-dimensional array which holds the data, this can be a lazy DiskArray"
    data::A
    "Metadata properties describing the content of the data"
    properties::Dict{String}
    "Representation of the chunking of the data"
    chunks::GridChunks{N}
    "Cleaner objects to track which objects to tidy up when the YAXArray goes out of scope"
    cleaner::Vector{CleanMe}
    "Name of the Array"
    function YAXArray(axes, data, properties, chunks, cleaner)
        if ndims(data) != length(axes) # case: mismatched Arguments
            throw(
                ArgumentError(
                    "Can not construct YAXArray, supplied data dimension is $(ndims(data)) while the number of axes is $(length(axes))",
                ),
            )
        elseif ntuple(i -> length(axes[i]), ndims(data)) != size(data) # case: mismatched data dimensions: sizes of axes and data
            throw(
                ArgumentError(
                    "Can not construct YAXArray, supplied data size is $(size(data)) while axis lenghts are $(ntuple(i->length(axes[i]),ndims(data)))",
                ),
            )
        elseif ndims(chunks) != ndims(data)
            throw(ArgumentError("Can not construct YAXArray, supplied chunk dimension is $(ndims(chunks)) while the number of dims is $(length(axes))"))
        else
            axes = DD.format(axes, data)
            return new{eltype(data),ndims(data),typeof(data),typeof(axes)}(
                axes,
                data,
                properties,
                chunks,
                cleaner,
            )
        end
    end
end

name(::YAXArray) = NoName()

YAXArray(axes, data, properties = Dict{String,Any}(); cleaner = CleanMe[], chunks = eachchunk(data)) =
    YAXArray(axes, data, properties, chunks, cleaner)
YAXArray(axes,data,properties,cleaner) = YAXArray(axes,data,properties,eachchunk(data),cleaner)
function YAXArray(x::AbstractArray)
    ax = caxes(x)
    props = getattributes(x)
    chunks = eachchunk(x)
    YAXArray(ax, x, props,chunks=chunks)
end


# Overload the YAXArray constructor for dimensional data to use them inside of mapCube
YAXArray(dim::DD.Dimension) = YAXArray((dim,), dim.val)
# Base utility overloads
Base.size(a::YAXArray) = size(getdata(a))
Base.size(a::YAXArray, i::Int) = size(getdata(a), i)
#Base.size(a::YAXArray, desc) = size(a, findAxis(desc, a))
# overload dot syntax for YAXArray to provide direct access to axes
function Base.getproperty(a::YAXArray, s::Symbol)
    ax = name.(caxes(a))
    i = findfirst(isequal(s), ax)
    if i === nothing
        return getfield(a, s)
    else
        return DD.dims(a)[i]
    end
end
# because getproperty is overloaded, propertynames should be as well
function Base.propertynames(a::YAXArray, private::Bool=false)
    if private
        (DD.dim2key.(DD.dims(a))..., :axes, :data, :properties)
    else
        (DD.dim2key.(DD.dims(a))..., :axes, :data)
    end
end


Base.ndims(a::YAXArray{<:Any,N}) where {N} = N
Base.eltype(a::YAXArray{T}) where {T} = T
function Base.permutedims(c::YAXArray, p) 
    newaxes = caxes(c)[collect(p)]
    newchunks = DiskArrays.GridChunks(eachchunk(c).chunks[collect(p)])
    YAXArray(newaxes, permutedims(getdata(c), p), c.properties, newchunks, c.cleaner)
end

# DimensionalData overloads

DD.dims(x::YAXArray) = getfield(x,:axes)
DD.refdims(::YAXArray) = ()
DD.metadata(x::YAXArray) = getfield(x,:properties)

function DD.rebuild(A::YAXArray, data::AbstractArray, dims::Tuple, refdims::Tuple, name, metadata)
    #chunks = map(dims, eachchunk(data).chunks) do d, chunk
    #    @show d
    #    if d in A.axes
    #        @show d
    #        dind = findAxis(d, A)
    #        A.chunks.chunks[dind]
    #    else
    #       chunk
    #    end
    #end
    YAXArray(dims, data, metadata; cleaner=A.cleaner)#, chunks=GridChunks(chunks))
end

function caxes(x)
    #@show x
    #@show typeof(x)
    dims = map(enumerate(dimnames(x))) do a
        index, symbol = a
        values = YAXArrayBase.dimvals(x, index)
        DD.Dim{symbol}(values)
    end
    (dims... ,)
end
caxes(c::YAXArray) = getfield(c, :axes)
"""
    caxes

Embeds  Cube inside a new Cube
"""
Cubes.caxes(x::DD.Dimension) = (x,)

"""
    readcubedata(cube)

Given any array implementing the YAXArray interface it returns an in-memory [`YAXArray`](@ref) from it.
"""
function readcubedata(x)
    YAXArray(caxes(x), getindex_all(x), getattributes(x))
end

interpret_cubechunks(cs::NTuple{N,Int},cube) where N = DiskArrays.GridChunks(getdata(cube),cs)
interpret_cubechunks(cs::DiskArrays.GridChunks,_) = cs
interpret_dimchunk(cs::Integer,s) = DiskArrays.RegularChunks(cs,0,s)
interpret_dimchunk(cs::DiskArrays.ChunkType, _) = cs

function interpret_cubechunks(cs,cube)
    oldchunks = DiskArrays.eachchunk(cube).chunks
    for k in keys(cs)
        i = findAxis(k,cube)
        if i !== nothing
            dimchunk = interpret_dimchunk(cs[k],size(cube.data,i))
            oldchunks = Base.setindex(oldchunks,dimchunk,i)
        end
    end
    GridChunks(oldchunks)
end

"""
    setchunks(c::YAXArray,chunks)

Resets the chunks of a YAXArray and returns a new YAXArray. Note that this will not change the chunking of the underlying data itself, 
it will just make the data "look" like it had a different chunking. If you need a persistent on-disk representation
of this chunking, use `savecube` on the resulting array. The `chunks` argument can take one of the following forms:

- a `DiskArrays.GridChunks` object
- a tuple specifying the chunk size along each dimension
- an AbstractDict or NamedTuple mapping one or more axis names to chunk sizes

"""
setchunks(c::YAXArray,chunks) = YAXArray(c.axes,c.data,c.properties,interpret_cubechunks(chunks,c),c.cleaner)
cubechunks(c) = approx_chunksize(eachchunk(c))
DiskArrays.eachchunk(c::YAXArray) = c.chunks
getindex_all(a) = getindex(a, ntuple(_ -> Colon(), ndims(a))...).data

#=
function Base.getindex(x::YAXArray, i...) 
    if length(i)==1 && istable(first(i))
        batchextract(x,first(i))
    else
        getdata(x)[i...]
    end
end
=#


function batchextract(x,i)
    # This function should be documented and moved to DimensionalData
    sch = schema(i)
    axinds = map(sch.names) do n
        findAxis(n,x)
    end
    tcols = columns(i)
    #Try to find a column denoting new axis name and values
    newaxcol = nothing
    
    if any(isnothing,axinds)
        allnothings = findall(isnothing,axinds)
        if length(allnothings) == 1
            newaxcol = allnothings[1]
        end
        tcols = (;[p[1:2] for p in zip(keys(tcols), values(tcols), axinds) if !isnothing(last(p))]...)
        axinds = filter(!isnothing,axinds)
    end
    
    allax = 1:ndims(x)
    axrem = setdiff(allax,axinds)
    ai1, ai2 = extrema(axinds)
    
    if !all(diff(sort(collect(axinds))).==1)
        #Axes to be extracted from are not consecutive in cube -> permute
        p = [1:(ai1-1);collect(axinds);filter(!in(axinds),ai1:ai2);(ai2+1:ndims(x))]
        x_perm = permutedims(x,p)
        return batchextract(x_perm,i)
    end

    cartinds = map(axinds,tcols) do iax,col
        axcur = caxes(x)[iax]
        map(col) do val
            axVal2Index(axcur,val)
        end
    end
    
    before = ntuple(_->Colon(),ai1-1)
    after = ntuple(_->Colon(),ndims(x)-ai2)
    sp = issorted(axinds) ? nothing : sortperm(collect(axinds))
    function makeindex(sp, inds...)
        if sp === nothing
            CartesianIndex(inds...)
        else
            CartesianIndex(inds[sp]...)
        end
    end
    indlist = makeindex.(Ref(sp),cartinds...)
    d = getdata(x)[before...,indlist,after...]
    cax = caxes(x)
    newax = if newaxcol == nothing
        outaxis_from_data(cax,axinds,indlist)
    else
        outaxis_from_column(i,newaxcol)
    end
    outax = Tuple([axcopy(a) for a in cax][axrem]...)
    insert!(outax,minimum(axinds),newax)
    YAXArray(outax,d,x.properties)
end

function outaxis_from_column(tab,icol)
    axdata = columns(tab)[icol]
    axname = schema(tab).names[icol]
    if eltype(axdata) <: AbstractString ||
        (!issorted(axdata) && !issorted(axdata, rev = true))
        DD.rebuild(DD.key2dim(Symbol(axname)), axdata)
    else
        DD.rebuild(DD.key2dim(Symbol(axname)), axdata)
    end
end

function outaxis_from_data(cax,axinds,indlist)
    mergeaxes = getindex.(Ref(cax),axinds)
    mergenames = axname.(mergeaxes)
    newname = join(mergenames,'_')
    minai = minimum(axinds)
    mergevals = map(indlist) do i
        broadcast(mergeaxes,axinds) do ax,ai
            ax.values[i[ai-minai+1]]
        end
    end
    DD.rebuild(DD.key2dim(Symbol(newname)), mergevals)
end
chunkoffset(c) = grid_offset(eachchunk(c))

# Implementation for YAXArrayBase interface
YAXArrayBase.dimvals(x::YAXArray, i) = caxes(x)[i].val
YAXArrayBase.dimname(x::YAXArray, i) = DD.dim2key(DD.dims(x)[i])
YAXArrayBase.getattributes(x::YAXArray) = x.properties
YAXArrayBase.iscontdim(x::YAXArray, i) = isa(caxes(x)[i], RangeAxis)
YAXArrayBase.getdata(x::YAXArray) = getfield(x, :data)
function YAXArrayBase.yaxcreate(::Type{YAXArray}, data, dimnames, dimvals, atts)
    axlist = tuple(map(dimnames, dimvals) do dn, dv
        DD.Dim{dn}(dv)
    end...)
    if any(in(keys(atts)), ["missing_value", "scale_factor", "add_offset"]) && !(eltype(data) >: Missing)
        data = CFDiskArray(data, atts)
    end
    YAXArray(axlist, data, atts)
end
YAXArrayBase.iscompressed(c::YAXArray) = _iscompressed(getdata(c))
_iscompressed(c::DiskArrays.PermutedDiskArray) = _iscompressed(c.a.parent)
_iscompressed(c::DiskArrays.SubDiskArray) = _iscompressed(c.v.parent)
_iscompressed(c) = YAXArrayBase.iscompressed(c)

# lift renameaxis functionality from Axes.jl to YAXArrays
renameaxis!(c::YAXArray, p::Pair) = DD.set(c, Symbol(first(p)) => last(p))

#=
function renameaxis!(c::YAXArray, p::Pair)
    #This needs to be deleted, because DimensionalData cannot update the axlist
    # Because this is a tuple instead of a vector
    axlist = caxes(c)
    i = findAxis(p[1], axlist)
    axlist[i] = renameaxis(axlist[i], p[2])
    c
end
function renameaxis!(c::YAXArray, p::Pair{<:Any,<:CubeAxis})
    i = findAxis(p[1], caxes(c))
    i === nothing && throw(ArgumentError("$(p[1]) Axis not found"))
    length(caxes(c)[i].values) == length(p[2].values) ||
        throw(ArgumentError("Length of replacement axis must equal length of old axis"))
    caxes(c)[i] = p[2]
    c
end
=#
function _subsetcube end

function subsetcube(z::YAXArray{T}; kwargs...) where {T}
    newaxes, substuple = _subsetcube(z, collect(Any, map(Base.OneTo, size(z))); kwargs...)
    newdata = view(getdata(z), substuple...)
    YAXArray(newaxes, newdata, z.properties, cleaner=z.cleaner)
end

sorted(x, y) = x < y ? (x, y) : (y, x)

#TODO move everything that is subset-related to its own file or to axes.jl
#=
interpretsubset(subexpr::Union{CartesianIndices{1},LinearIndices{1}}, ax) =
    subexpr.indices[1]
interpretsubset(subexpr::CartesianIndex{1}, ax) = subexpr.I[1]
interpretsubset(subexpr, ax) = axVal2Index(ax, subexpr, fuzzy=true)
function interpretsubset(subexpr::NTuple{2,Any}, ax)
    x, y = sorted(subexpr...)
    Colon()(sorted(axVal2Index_lb(ax, x), axVal2Index_ub(ax, y))...)
end
interpretsubset(subexpr::NTuple{2,Int}, ax::RangeAxis{T}) where {T<:TimeType} =
    interpretsubset(map(T, subexpr), ax)
interpretsubset(subexpr::UnitRange{<:Integer}, ax::RangeAxis{T}) where {T<:TimeType} =
    interpretsubset(T(first(subexpr)) .. T(last(subexpr) + 1), ax)
interpretsubset(subexpr::Interval, ax) = interpretsubset((subexpr.left, subexpr.right), ax)
interpretsubset(subexpr::AbstractVector, ax::CategoricalAxis) =
    axVal2Index.(Ref(ax), subexpr, fuzzy=true)
=#

function _subsetcube(z, subs; kwargs...)
    kwargs = Dict{Any,Any}(kwargs)
    for f in YAXDefaults.subsetextensions
        f(kwargs)
    end
    newaxes = deepcopy(collect(DD.Dimension, caxes(z)))
    foreach(kwargs) do kw
        axdes, subexpr = kw
        axdes = string(axdes)
        iax = findAxis(axdes, caxes(z))
        if isa(iax, Nothing)
            throw(ArgumentError("Axis $axdes not found in cube"))
        else
            oldax = newaxes[iax]
            subinds = interpretsubset(subexpr, oldax)
            subs2 = subs[iax][subinds]
            subs[iax] = subs2
            if !isa(subinds, AbstractVector) && !isa(subinds, AbstractRange)
                newaxes[iax] = axcopy(oldax, oldax.values[subinds:subinds])
            else
                newaxes[iax] = axcopy(oldax, oldax.values[subinds])
            end
        end
    end
    substuple = ntuple(i -> subs[i], length(subs))
    inewaxes = findall(i -> isa(i, AbstractVector), substuple)
    newaxes = newaxes[inewaxes]
    @assert length.(newaxes) ==
            map(length, filter(i -> isa(i, AbstractVector), collect(substuple)))
    newaxes, substuple
end


function Base.getindex(a::YAXArray, args::DD.Dimension...; kwargs...) 
    kwargsdict = Dict{Any,Any}(kwargs...)
    for ext in YAXDefaults.subsetextensions
        ext(kwargsdict)
    end
    d2 = Dict()
    for (k,v) in kwargsdict
        d = getAxis(k,a)
        if d !== nothing
            if d isa DD.Ti
                if v isa UnitRange{Int}
                    v = Date(first(v))..Date(last(v),12,31)
                end
                d2[:Ti] = v
            else
                d2[DD.name(d)] = v
            end
        else
            d2[k] = v
        end
    end
    view(a, args...; d2...)
end

Base.read(d::YAXArray) = getindex_all(d)

function formatbytes(x)
    exts = ["bytes", "KB", "MB", "GB", "TB"]
    i = 1
    while x >= 1024
        i = i + 1
        x = x / 1024
    end
    return string(round(x, digits=2), " ", exts[i])
end
cubesize(c::YAXArray{T}) where {T} = (sizeof(T)) * prod(map(length, caxes(c)))
cubesize(::YAXArray{T,0}) where {T} = sizeof(T)

getCubeDes(::DD.Dimension) = "Cube axis"
getCubeDes(::YAXArray) = "YAXArray"
getCubeDes(::Type{T}) where {T} = string(T)

function DD.show_after(io::IO,mime, c::YAXArray)
    foreach(getattributes(c)) do p
        if p[1] in ("labels", "name", "units")
            println(io, p[1], ": ", p[2])
        end
    end
    println(io, "Total size: ", formatbytes(cubesize(c)))
end



include("TransformedCubes.jl")
include("Slices.jl")
include("Rechunker.jl")
end #module
