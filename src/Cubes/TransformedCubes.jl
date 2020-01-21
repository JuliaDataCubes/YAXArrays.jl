export ConcatCube, concatenateCubes
export mergeAxes
import ..ESDLTools.getiperm
import ..Cubes: _read, gethandle, caxes, iscompressed, cubechunks, chunkoffset

mutable struct PermCube{T,N,C} <: AbstractCubeData{T,N}
  parent::C
  perm::NTuple{N,Int}
end
Base.size(x::PermCube)=ntuple(i->size(x.parent,x.perm[i]),ndims(x))
Base.size(x::PermCube,i)=size(x.parent,x.perm[i])
caxes(v::PermCube)=caxes(v.parent)[collect(v.perm)]
getCubeDes(v::PermCube)=getCubeDes(v.parent)
permtuple(t,perm)=ntuple(i->t[perm[i]],length(t))
iscompressed(c::PermCube)=iscompressed(c.parent)
cubechunks(c::PermCube)=cubechunks(c.parent)[collect(c.perm)]
chunkoffset(c::PermCube)=chunkoffset(c.parent)[collect(c.perm)]
function subsetcube(p::PermCube; kwargs...)
  subscube = subsetcube(p.parent;kwargs...)
  lostaxes = setdiff(caxes(p.parent), caxes(subscube))
  ilose    = map(ax->findAxis(ax,p.parent), lostaxes)
  losemap  = cumsum([!in(i,ilose) for i=1:ndims(p.parent)])
  losemap[findall([in(i,ilose) for i=1:ndims(p.parent)])] .= 0
  newperm = []
  foreach(i->losemap[i]==0 ? nothing : push!(newperm,losemap[i]),p.perm)
  isempty(newperm) ? subscube : permutedims(subscube,(newperm...,))
end
function _read(x::PermCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  perm=x.perm
  iperm=getiperm(perm)
  r2=CartesianIndices((permtuple(r.indices,iperm)))
  sr = size(r2)
  aout = zeros(T,sr...)
  _read(x.parent,aout,r2)
  permutedims!(thedata,aout,perm)

end
Base.permutedims(x::AbstractCubeData{T,N},perm) where {T,N}=PermCube{T,N,typeof(x)}(x,perm)
function gethandle(c::PermCube,block_size)
  handle = gethandle(c.parent)
  PermutedDimsArray(handle,c.perm)
end

import Base.Iterators.product


mutable struct TransformedCube{T,N,F} <: AbstractCubeData{T,N}
  parents
  op::F
  cubeaxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

function Base.map(op, incubes::AbstractCubeData...; T::Type=eltype(incubes[1]))
  axlist=copy(caxes(incubes[1]))
  N=ndims(incubes[1])
  for i=2:length(incubes)
    all(caxes(incubes[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    ndims(incubes[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(incubes)...)
  TransformedCube{T,N,typeof(op)}(incubes,op,axlist,props)
end

Base.size(x::TransformedCube)=size(x.parents[1])
Base.size(x::TransformedCube{T,N},i) where {T,N}=size(x.parents[1],i)
caxes(v::TransformedCube)=v.cubeaxes
getCubeDes(v::TransformedCube)="Transformed cube $(getCubeDes(v.parents[1]))"
iscompressed(v::TransformedCube)=any(iscompressed,v.parents)
cubechunks(v::TransformedCube)=cubechunks(v.parents[1])
chunkoffset(v::TransformedCube)=chunkoffset(v.parents[1])
function subsetcube(v::TransformedCube{T}; kwargs...) where T
  newcubes = map(i->subsetcube(i; kwargs...), v.parents)
  map(v.op, newcubes..., T=T)
end


using Base.Cartesian
function _read(x::TransformedCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  ainter=map(x.parents) do c
    aouti=Array{eltype(c)}(undef,size(thedata))
    _read(c,aouti,r)
    aouti
  end
  map!(x.op,thedata,ainter...)
  return thedata
end

ops2 = [:+, :-,:/, :*, :max, :min]
for op in ops2
  eval(:(Base.$(op)(x::AbstractCubeData, y::AbstractCubeData)=map($op, x,y)))
  eval(:(Base.$(op)(x::AbstractCubeData, y::Number)          =map(i->$(op)(i,y),x)))
  eval(:(Base.$(op)(x::Number, y::AbstractCubeData)          =map(i->$(op)(x,i),y)))
end

ops1 = [:sin, :cos, :log, :log10, :exp, :abs]
for op in ops1
  eval(:(Base.$(op)(x::AbstractCubeData)=map($op, x)))
end




"""
    ConcatCube

Concatenate a list of cubes of the same type and axes to a composite cube.
"""
mutable struct ConcatCube{T,N} <: AbstractCubeData{T,N}
  cubelist::Vector
  cataxis::CubeAxis
  cubeaxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

"""
    function concatenateCubes(cubelist, cataxis::CategoricalAxis)

Concatenates a vector of datacubes that have identical axes to a new single cube along the new
axis `cataxis`
"""
function concatenateCubes(cl,cataxis::CubeAxis)
  length(cataxis.values)==length(cl) || error("cataxis must have same length as cube list")
  axlist=copy(caxes(cl[1]))
  T=eltype(cl[1])
  N=ndims(cl[1])
  for i=2:length(cl)
    all(caxes(cl[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    eltype(cl[i])==T || error("All cubes must have the same element type, cube number $i does not match")
    ndims(cl[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(cl)...)
  ConcatCube{T,N+1}(cl,cataxis,axlist,props)
end
function concatenateCubes(;kwargs...)
  cubenames = String[]
  for (n,c) in kwargs
    push!(cubenames,string(n))
  end
  cubes = map(i->i[2],collect(kwargs))
  findAxis("Variable",cubes[1]) === nothing || error("Input cubes must not contain a variable kwarg concatenation")
  concatenateCubes(cubes, CategoricalAxis("Variable",cubenames))
end
Base.size(x::ConcatCube)=(size(x.cubelist[1])...,length(x.cataxis))
Base.size(x::ConcatCube{T,N},i) where {T,N}=i==N ? length(x.cataxis) : size(x.cubelist[1],i)
caxes(v::ConcatCube)=[v.cubeaxes;v.cataxis]
iscompressed(x::ConcatCube)=any(iscompressed,x.cubelist)
cubechunks(x::ConcatCube)=(cubechunks(x.cubelist[1])...,1)
chunkoffset(x::ConcatCube)=(chunkoffset(x.cubelist[1])...,0)
getCubeDes(v::ConcatCube)="Collection of $(getCubeDes(v.cubelist[1]))"
using Base.Cartesian
function _read(x::ConcatCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  rnew = CartesianIndices(r.indices[1:end-1])
  for (j,i)=enumerate(r.indices[end])
    a=selectdim(thedata,N,j)
    _read(x.cubelist[i],a,rnew)
  end
  return thedata
end
function _write(x::ConcatCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  rnew = CartesianIndices(r.indices[1:end-1])
  for (j,i)=enumerate(r.indices[end])
    a=selectdim(thedata,N,j)
    _write(x.cubelist[i],a,rnew)
  end
  return nothing
end

using RecursiveArrayTools
function gethandle(c::ConcatCube,block_size)
  VectorOfArray(map(gethandle,c.cubelist))
end

struct SplitDimsCube{T,N,C} <: AbstractCubeData{T,N}
    parent::C
    newaxes
    newchunks::Tuple{Int,Int}
    isplit::Int
end

export splitdim
"""
Splits an axis into two, reshaping the data cube into a higher-order cube.
"""
function splitdim(c, dimtosplit, newdims)
    isplit = findAxis(dimtosplit,c)
    isplit ===nothing && error("Could not find axis in cube")
    axesold = caxes(c)
    length(axesold[isplit]) == prod(length.(newdims)) || error("Size of new dimensions don't match the old one")
    all(i->isa(i,CubeAxis), newdims) || error("Newdims must be a list of cube axes")
    splitchunk = cubechunks(c)[isplit]
    newchunks = if splitchunk==length(newdims[1])
        (length(newdims[1]),1)
    elseif splitchunk>length(newdims[1])
        iszero(rem(splitchunk,length(newdims[1]))) || error("You can not do this split since chunks woudl overlap")
        (length(newdims[1]),splitchunk ÷ length(newdims[1]))
    else
        iszero(rem(length(newdims[1]),splitchunk)) || error("You can not do this split since chunks woudl overlap")
        (length(newdims[1]) ÷ splitchunk, 1)
    end
    SplitDimsCube{eltype(c), ndims(c)+1, typeof(c)}(c,(newdims...,),newchunks,isplit)
end

function Base.size(x::SplitDimsCube)
    sp = size(x.parent)
    (sp[1:isplit-1]...,length.(newaxes)...,sp[isplit+1:end]...)
end
Base.size(x::SplitDimsCube{T,N},i) where {T,N} = if i<x.isplit
    size(x.parent,i)
elseif i==x.isplit
    length(x.newaxes[1])
elseif i==x.isplit+1
    length(x.newaxes[2])
else
    size(x.parent,i+1)
end
function caxes(v::SplitDimsCube)
    axold = caxes(v.parent)
    [axold[1:v.isplit-1]...;v.newaxes...;axold[v.isplit+1:end]...]
end
getCubeDes(v::SplitDimsCube)=getCubeDes(v.parent)
iscompressed(v::SplitDimsCube)=iscompressed(v.parent)
function cubechunks(v::SplitDimsCube)
    cc = cubechunks(v.parent)
    (cc[1:v.isplit-1]...,v.newchunks...,cc[v.isplit+1:end]...)
end
function chunkoffset(v::SplitDimsCube)
    co = chunkoffset(v.parent)
    #This can not be determined, so we just assume zero here
    (co[1:v.isplit-1]...,0,0,co[v.isplit+1:end]...)
end
function subsetcube(v::SplitDimsCube; kwargs...)
    newax = collect(v.newaxes)
    foreach(kwargs) do (k,v)
        findAxis(k,newax) !== nothing && error("Subsetting split axes is not yet supported")
    end
    newcube = subsetcube(v.parent; kwargs...)
    splitdim(newcube,caxes(newcube)[isplit],v.newaxes)
end
using Base.Cartesian
function _read(x::SplitDimsCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  r1 = r.indices[x.isplit]
  r2 = r.indices[x.isplit+1]
  if length(r2)==1 && length(r1)==length(x.newaxes[1])
    error("This read is not yet implemented")
  end
  istart = (first(r2)-1)*size(x,x.isplit) + first(r1)
  iend   = (last(r2)-1) *size(x,x.isplit) + last(r1)
  indsold = r.indices
  inew = CartesianIndices((r.indices[1:x.isplit-1]...,istart:iend,r.indices[x.isplit+2:end]...))
  a2 = reshape(thedata,size(inew))
  _read(x.parent,a2,inew)
  return thedata
end
