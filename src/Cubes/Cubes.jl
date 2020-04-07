"""
The functions provided by ESDL are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
using DiskArrays: DiskArrays, eachchunk
using Distributed: myid
using Dates: TimeType
using IntervalSets: Interval, (..)
using Base.Iterators: take, drop
using ..ESDL: workdir

"""
    AbstractCubeData{T,N}

Supertype of all cubes. `T` is the data type of the cube and `N` the number of
dimensions. Beware that an `AbstractCubeData` does not implement the `AbstractArray`
interface. However, the `ESDL` functions [`mapCube`](@ref), [`reduceCube`](@ref),
[`readcubedata`](@ref), [`plotMAP`](@ref) and [`plotXY`](@ref) will work on any subtype
of `AbstractCubeData`
"""
abstract type AbstractCubeData{T,N} end

Base.eltype(::AbstractCubeData{T}) where T = T
Base.ndims(::AbstractCubeData{<:Any,N}) where N = N

"""
    readCubeData(cube::AbstractCubeData)

Given any type of `AbstractCubeData` returns a [`CubeMem`](@ref) from it.
"""
function readcubedata(x)
  s=size(x)
  aout = zeros(eltype(x),s...)
  r=CartesianIndices(s)
  _read(x,aout,r)
  CubeMem(collect(CubeAxis,caxes(x)),aout,getattributes(x))
end

"""
This function calculates a subset of a cube's data
"""
function subsetcube end

function _read end

"Returns the axes of a Cube"
caxes(c::AbstractCubeData)=error("Axes function not implemented for $(typeof(c))")

getattributes(::AbstractCubeData)=Dict{String,Any}()

"Chunks, if given"
cubechunks(c::AbstractCubeData) = (size(c,1),map(i->1,2:ndims(c))...)

"Offset of the first chunk"
chunkoffset(c::AbstractCubeData) = ntuple(i->0,ndims(c))

function iscompressed end

"Supertype of all subtypes of the original data cube"
abstract type AbstractSubCube{T,N} <: AbstractCubeData{T,N} end


"Supertype of all in-memory representations of a data cube"
abstract type AbstractCubeMem{T,N} <: AbstractCubeData{T,N} end

include("Axes.jl")
using .Axes: CubeAxis, RangeAxis, CategoricalAxis, findAxis, getAxis, axVal2Index,
  axname, axsym, axVal2Index_lb, axVal2Index_ub, renameaxis

mutable struct CleanMe
  path::String
  persist::Bool
  function CleanMe(path::String,persist::Bool)
    c = new(path,persist)
    finalizer(clean,c)
    c
  end
end
function clean(c::CleanMe)
  if !c.persist && myid()==1
    if !isdir(c.path)
      @warn "Cube directory $(c.path) does not exist. Can not clean"
    else
      rm(c.path,recursive=true)
    end
  end
end

"""
    ESDLArray{T,N} <: AbstractCubeMem{T,N}

An in-memory data cube. It is returned by applying `mapCube` when
the output cube is small enough to fit in memory or by explicitly calling
[`readcubedata`](@ref) on any type of cube.

### Fields

* `axes` a `Vector{CubeAxis}` containing the Axes of the Cube
* `data` N-D array containing the data

"""
struct ESDLArray{T,N,A<:AbstractArray{T,N},AT} <: AbstractCubeData{T,N}
  axes::AT
  data::A
  properties::Dict{String}
  cleaner::Vector{CleanMe}
end
include("cubeinterface.jl")

ESDLArray(axes,data,properties=Dict{String,Any}(); cleaner=CleanMe[]) = ESDLArray(axes,data,properties, cleaner)
function ESDLArray(x::AbstractArray)
  ax = caxes(x)
  props = getattributes(x)
  ESDLArray(ax,x,props)
end
Base.size(a::ESDLArray) = size(a.data)
Base.size(a::ESDLArray,i::Int) = size(a.data,i)
Base.permutedims(c::ESDLArray,p)=ESDLArray(c.axes[collect(p)],permutedims(c.data,p),c.properties,c.cleaner)
caxes(c::ESDLArray)=c.axes
function caxes(x)
  map(enumerate(dimnames(x))) do i,s
    v = dimvals(x,i)
    iscontdim(x,i) ? RangeAxis(s,v) : CategoricalAxis(s,v)
  end
end
iscompressed(c::ESDLArray)=iscompressed(c.data)
iscompressed(c::DiskArrays.PermutedDiskArray) = iscompressed(c.a.parent)
iscompressed(c::DiskArrays.SubDiskArray) = iscompressed(c.v.parent)
cubechunks(c::ESDLArray)=common_size(eachchunk(c.data))
cubechunks(x) = common_size(eachchunk(x))
common_size(a::DiskArrays.GridChunks) = a.chunksize
function common_size(a)
  ntuple(ndims(a)) do idim
    otherdims = setdiff(1:ndims(a),idim)
    allengths = map(i->length(i.indices[idim]),a)
    for od in otherdims
      allengths = unique(allengths,dims=od)
    end
    @assert length(allengths) == size(a,idim)
    length(allengths)<3 ? allengths[1] : allengths[2]
  end
end

chunkoffset(c::ESDLArray)=common_offset(eachchunk(c.data))
chunkoffset(x) = common_offset(eachchunk(x))
common_offset(a::DiskArrays.GridChunks) = a.offset
function common_offset(a)
  ntuple(ndims(a)) do idim
    otherdims = setdiff(1:ndims(a),idim)
    allengths = map(i->length(i[idim]),a)
    for od in otherdims
      allengths = unique(allengths,dims=od)
    end
    @assert length(allengths) == size(a,idim)
    length(allengths)<3 ? 0 : allengths[2]-allengths[1]
  end
end
readcubedata(c::ESDLArray)=ESDLArray(c.axes,Array(c.data),c.properties,CleanMe[])

function renameaxis!(c::ESDLArray,p::Pair)
  i = findAxis(p[1],c.axes)
  c.axes[i]=renameaxis(c.axes[i],p[2])
  c
end
function renameaxis!(c::ESDLArray,p::Pair{<:Any,<:CubeAxis})
  i = findAxis(p[1],c.axes)
  i === nothing && throw(ArgumentError("Axis not found"))
  length(c.axes[i].values) == length(p[2].values) || throw(ArgumentError("Length of replacement axis must equal length of old axis"))
  c.axes[i]=p[2]
  c
end

# function getSubRange(c::AbstractArray,i...;write::Bool=true)
#   length(i)==ndims(c) || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
#   return view(c,i...)
# end
# getSubRange(c::Tuple{AbstractArray{T,0},AbstractArray{UInt8,0}};write::Bool=true) where {T}=c

function _subsetcube end

function subsetcube(z::ESDLArray{T};kwargs...) where T
  newaxes, substuple = _subsetcube(z,collect(Any,map(Base.OneTo,size(z)));kwargs...)
  newdata = view(z.data,substuple...)
  ESDLArray(newaxes,newdata,z.properties,cleaner = z.cleaner)
end

sorted(x,y) = x<y ? (x,y) : (y,x)

#TODO move everything that is subset-related to its own file or to axes.jl
interpretsubset(subexpr::Union{CartesianIndices{1},LinearIndices{1}},ax) = subexpr.indices[1]
interpretsubset(subexpr::CartesianIndex{1},ax)   = subexpr.I[1]
interpretsubset(subexpr,ax)                      = axVal2Index(ax,subexpr,fuzzy=true)
function interpretsubset(subexpr::NTuple{2,Any},ax)
  x, y = sorted(subexpr...)
  Colon()(sorted(axVal2Index_lb(ax,x),axVal2Index_ub(ax,y))...)
end
interpretsubset(subexpr::NTuple{2,Int},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(map(T,subexpr),ax)
interpretsubset(subexpr::UnitRange{Int64},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(T(first(subexpr))..T(last(subexpr)+1),ax)
interpretsubset(subexpr::Interval,ax)       = interpretsubset((subexpr.left,subexpr.right),ax)
interpretsubset(subexpr::AbstractVector,ax::CategoricalAxis)      = axVal2Index.(Ref(ax),subexpr,fuzzy=true)


function _subsetcube(z::AbstractCubeData, subs;kwargs...)
  if :region in keys(kwargs)
    kwargs = collect(Any,kwargs)
    ireg = findfirst(i->i[1]==:region,kwargs)
    reg = splice!(kwargs,ireg)
    haskey(known_regions,reg[2]) || error("Region $(reg[2]) not known.")
    lon1,lat1,lon2,lat2 = known_regions[reg[2]]
    push!(kwargs,:lon=>lon1..lon2)
    push!(kwargs,:lat=>lat1..lat2)
  end
  newaxes = deepcopy(caxes(z))
  foreach(kwargs) do kw
    axdes,subexpr = kw
    axdes = string(axdes)
    iax = findAxis(axdes,caxes(z))
    if isa(iax,Nothing)
      throw(ArgumentError("Axis $axdes not found in cube"))
    else
      oldax = newaxes[iax]
      subinds = interpretsubset(subexpr,oldax)
      subs2 = subs[iax][subinds]
      subs[iax] = subs2
      if !isa(subinds,AbstractVector) && !isa(subinds,AbstractRange)
        newaxes[iax] = axcopy(oldax,oldax.values[subinds:subinds])
      else
        newaxes[iax] = axcopy(oldax,oldax.values[subinds])
      end
    end
  end
  substuple = ntuple(i->subs[i],length(subs))
  inewaxes = findall(i->isa(i,AbstractVector),substuple)
  newaxes = newaxes[inewaxes]
  @assert length.(newaxes) == map(length,filter(i->isa(i,AbstractVector),collect(substuple)))
  newaxes, substuple
end

include(joinpath(@__DIR__,"../DatasetAPI/countrydict.jl"))

Base.getindex(a::AbstractCubeData;kwargs...) = subsetcube(a;kwargs...)

Base.read(d::AbstractCubeData) = getindex(d,fill(Colon(),ndims(d))...)

function formatbytes(x)
  exts=["bytes","KB","MB","GB","TB"]
  i=1
  while x>=1024
    i=i+1
    x=x/1024
  end
  return string(round(x, digits=2)," ",exts[i])
end
cubesize(c::AbstractCubeData{T}) where {T}=(sizeof(T)+1)*prod(map(length,caxes(c)))
cubesize(c::AbstractCubeData{T,0}) where {T}=sizeof(T)+1

getCubeDes(c::AbstractSubCube)="Data Cube view"
getCubeDes(::CubeAxis)="Cube axis"
getCubeDes(c::ESDLArray)="ESDL data cube"
function Base.show(io::IO,c::AbstractCubeData)
    println(io,getCubeDes(c), " with the following dimensions")
    for a in caxes(c)
        println(io,a)
    end

    foreach(getattributes(c)) do p
      if p[1] in ("labels","name","units")
        println(io,p[1],": ",p[2])
      end
    end
    println(io,"Total size: ",formatbytes(cubesize(c)))
end


using Markdown
struct ESDLVarInfo
  project::String
  longname::String
  units::String
  url::String
  comment::String
  reference::String
end
Base.isless(a::ESDLVarInfo, b::ESDLVarInfo) = isless(string(a.project, a.longname),string(b.project, b.longname))

import Base.show
function show(io::IO,::MIME"text/markdown",v::ESDLVarInfo)
    un=v.units
    url=v.url
    re=v.reference
    pr = v.project
    ln = v.longname
    co = v.comment
    mdt=md"""
### $ln
*$(co)*

* **Project** $(pr)
* **units** $(un)
* **Link** $(url)
* **Reference** $(re)
"""
    mdt[3].items[1][1].content[3]=[" $pr"]
    mdt[3].items[2][1].content[3]=[" $un"]
    mdt[3].items[3][1].content[3]=[" $url"]
    mdt[3].items[4][1].content[3]=[" $re"]
    show(io,MIME"text/markdown"(),mdt)
end
show(io::IO,::MIME"text/markdown",v::Vector{ESDLVarInfo})=foreach(x->show(io,MIME"text/markdown"(),x),v)
using Zarr: zname

"""
    cubeinfo(cube)

Shows the metadata and citation information on variables contained in a cube.
"""
function cubeinfo(ds::ESDLArray, variable="unknown")
    p = ds.properties
    vi=ESDLVarInfo(
      get(p,"project_name", "unknown"),
      get(p,"long_name",variable),
      get(p,"units","unknown"),
      get(p,"url","no link"),
      get(p,"comment",variable),
      get(p,"references","no reference")
    )
end

include("TransformedCubes.jl")
end
