export ConcatCube, concatenateCubes
export mergeAxes
import ..ESDLTools.getiperm
import ..Cubes: _read, needshandle, gethandle, getcachehandle, handletype

mutable struct PermCube{T,N,C} <: AbstractCubeData{T,N}
  parent::C
  perm::NTuple{N,Int}
end
Base.size(x::PermCube)=ntuple(i->size(x.parent,x.perm[i]),ndims(x))
Base.size(x::PermCube,i)=size(x.parent,x.perm[i])
axes(v::PermCube)=axes(v.parent)[collect(v.perm)]
getCubeDes(v::PermCube)=getCubeDes(v.parent)
permtuple(t,perm)=ntuple(i->t[perm[i]],length(t))
function _read(x::PermCube{T,N},thedata::Tuple{Any,Any},r::CartesianIndices{N}) where {T,N}
  perm=x.perm
  iperm=getiperm(perm)
  r2=CartesianIndices(CartesianIndex(permtuple(r.start.I,iperm)),CartesianIndex(permtuple(r.stop.I,iperm)))
  sr = ntuple(i->r.stop.I[iperm[i]]-r.start.I[iperm[i]]+1,N)
  aout,mout=zeros(T,sr...),zeros(UInt8,sr...)
  _read(x.parent,(aout,mout),r2)
  permutedims!(thedata[1],aout,perm)
  permutedims!(thedata[2],mout,perm)
end
Base.permutedims(x::AbstractCubeData{T,N},perm) where {T,N}=PermCube{T,N,typeof(x)}(x,perm)
gethandle(c::PermCube,block_size)=gethandle(c,block_size,handletype(c.parent))
function gethandle(c::PermCube,block_size,::ViewHandle)
  data,mask = gethandle(c.parent)
  PermutedDimsArray(data,c.perm),PermutedDimsArray(mask,c.perm)
end
gethandle(c::PermCube,block_size,::CacheHandle) = getcachehandle(c,CartesianIndex(block_size))

import Base.Iterators.product

mutable struct MergedAxisCube{T,N,C} <: AbstractCubeData{T,N}
  parent::C
  imerge::Int
  newAxes::Vector{CubeAxis}
end
getCubeDes(v::MergedAxisCube)=getCubeDes(v.parent)
function axes(v::MergedAxisCube)
  v.newAxes
end
cubeproperties(v::MergedAxisCube)=cubeproperties(v.parent)
Base.size(x::MergedAxisCube)=ntuple(i->length(x.newAxes[i]),ndims(x))
Base.size(x::MergedAxisCube,i)=length(x.newAxes[i])
function _read(x::MergedAxisCube{T,N},thedata::Tuple{Any,Any},r::CartesianIndices{N}) where {T,N}

  s1,s2 = size(x.parent)[x.imerge:x.imerge+1]
  sr = r.start.I[x.imerge],r.stop.I[x.imerge]

  sta = r.start.I
  sto = r.stop.I
  aout,mout = thedata
  saout=size(aout)
  if sr[2]-sr[1]==0
        sr2 = ind2sub((s1,s2),sr[1])
        aout2 = reshape(aout,saout[1:x.imerge-1]...,1,1,saout[x.imerge+1:end]...)
        mout2 = reshape(mout,saout[1:x.imerge-1]...,1,1,saout[x.imerge+1:end]...)
    r2    = CartesianIndices(CartesianIndex((sta[1:x.imerge-1]...,sr2[1],sr2[2],sta[x.imerge+1:end]...)),CartesianIndex((sto[1:x.imerge-1]...,sr2[1],sr2[2],sto[x.imerge+1:end]...)))
        _read(x.parent,(aout2,mout2),r2)
  elseif sr[2]-sr[1]==size(x,x.imerge)-1
        aout2 = reshape(aout,saout[1:x.imerge-1]...,s1,s2,saout[x.imerge+1:end]...)
        mout2 = reshape(mout,saout[1:x.imerge-1]...,s1,s2,saout[x.imerge+1:end]...)
    r2    = CartesianIndices(CartesianIndex((sta[1:x.imerge-1]...,1,1,sta[x.imerge+1:end]...)),CartesianIndex((sto[1:x.imerge-1]...,s1,s2,sto[x.imerge+1:end]...)))
    _read(x.parent,(aout2,mout2),r2)
  else
    error("Cropping into mergedaxiscubes not yet possible")
  end
end
gethandle(c::MergedAxisCube,block_size)=gethandle(c,block_size,handletype(c.parent))
function gethandle(c::MergedAxisCube,block_size,::ViewHandle)
  data,mask = gethandle(c.parent)
  s = size(data)
  reshape(data,s[1:c.imerge-1]...,s[c.imerge]*s[c.imerge+1],s[c.imerge+2:end]...), reshape(mask,s[1:c.imerge-1]...,s[c.imerge]*s[c.imerge+1],s[c.imerge+2:end]...)
end
gethandle(c::MergedAxisCube,block_size,::CacheHandle) = getcachehandle(c,CartesianIndex(block_size))


function mergeAxes(c::AbstractCubeData,a1,a2)
    i1=findAxis(a1,c)
    i2=findAxis(a2,c)
    abs(i1-i2)==1 || error("Can only merge axes that are consecutive in cube")
    ax = axes(c)
    imerge=min(i1,i2)
    a1 = ax[imerge]
    a2 = ax[imerge+1]
    newAx = CategoricalAxis(string(axname(a1),"_x_",axname(a2)),product(a1.values,a2.values))
    MergedAxisCube{eltype(c),ndims(c)-1,typeof(c)}(c,min(i1,i2),[ax[1:imerge-1];newAx;ax[imerge+2:end]])
end


mutable struct TransformedCube{T,N,F} <: AbstractCubeData{T,N}
  parents
  op::F
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

function Base.map(op, incubes::AbstractCubeData...; T::Type=eltype(incubes[1]))
  axlist=copy(axes(incubes[1]))
  N=ndims(incubes[1])
  for i=2:length(incubes)
    all(axes(incubes[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    ndims(incubes[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(incubes)...)
  TransformedCube{T,N,typeof(op)}(incubes,op,axlist,props)
end

gethandle(c::TransformedCube,block_size)=getcachehandle(c,CartesianIndex(block_size))

Base.size(x::TransformedCube)=size(x.parents[1])
Base.size(x::TransformedCube{T,N},i) where {T,N}=size(x.parents[1],i)
axes(v::TransformedCube)=v.cubeAxes
getCubeDes(v::TransformedCube)="Transformed cube $(getCubeDes(v.parents[1]))"
using Base.Cartesian
function _read(x::TransformedCube{T,N},thedata::Tuple,r::CartesianIndices{N}) where {T,N}
  aout,mout=thedata
  ainter=[]
  minter=[]
  for i=1:length(x.parents)
    c=x.parents[i]
    aouti=zeros(eltype(c),size(aout))
    mouti=zeros(UInt8,size(mout))
    _read(c,(aouti,mouti),r)
    push!(ainter,aouti)
    push!(minter,mouti)
  end
  map!(x.op,aout,ainter...)
  map!((x...)->reduce(|,x),mout,minter...)
  return aout,mout
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
  catAxis::CubeAxis
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

"""
    function concatenateCubes(cubelist, catAxis::CategoricalAxis)

Concatenates a vector of datacubes that have identical axes to a new single cube along the new
axis `catAxis`
"""
function concatenateCubes(cl,catAxis::CubeAxis)
  length(catAxis.values)==length(cl) || error("catAxis must have same length as cube list")
  axlist=copy(axes(cl[1]))
  T=eltype(cl[1])
  N=ndims(cl[1])
  for i=2:length(cl)
    all(axes(cl[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    eltype(cl[i])==T || error("All cubes must have the same element type, cube number $i does not match")
    ndims(cl[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(cl)...)
  ConcatCube{T,N+1}(cl,catAxis,axlist,props)
end
Base.size(x::ConcatCube)=(size(x.cubelist[1])...,length(x.catAxis))
Base.size(x::ConcatCube{T,N},i) where {T,N}=i==N ? length(x.catAxis) : size(x.cubelist[1],i)
axes(v::ConcatCube)=[v.cubeAxes;v.catAxis]
getCubeDes(v::ConcatCube)="Collection of $(getCubeDes(v.cubelist[1]))"
using Base.Cartesian
@generated function _read(x::ConcatCube{T,N},thedata::Tuple,r::CartesianIndices{N}) where {T,N}
  viewEx1=Expr(:call,:view,:aout,fill(Colon(),N-1)...,:j)
  viewEx2=Expr(:call,:view,:mout,fill(Colon(),N-1)...,:j)
  quote
    aout,mout=thedata
    rnew = CartesianRange(CartesianIndex(r.start.I[1:end-1]),CartesianIndex(r.stop.I[1:end-1]))
    for (j,i)=enumerate(r.start.I[end]:r.stop.I[end])
      a=$viewEx1
      m=$viewEx2
      _read(x.cubelist[i],(a,m),rnew)
    end
    return aout,mout
  end
end

using RecursiveArrayTools
gethandle(c::ConcatCube,block_size)=gethandle(c,block_size,handletype(c))
function gethandle(c::ConcatCube,block_size,::ViewHandle)
  data,mask = gethandle(c.cubelist[1])
  d = [data]
  m = [mask]
  for i=2:length(c.cubelist)
    data,mask = gethandle(c.cubelist[i])
    push!(d,data)
    push!(m,mask)
  end
  VectorOfArray(d),VectorOfArray(m)
end
gethandle(c::ConcatCube,block_size,::CacheHandle) = getcachehandle(c,CartesianIndex(block_size))
handletype(c::ConcatCube)=any(i->handletype(i)==CacheHandle(),c.cubelist) ? CacheHandle() : ViewHandle()

export SliceCube
mutable struct SliceCube{T,N,iax} <: AbstractCubeData{T,N}
  parent
  ival::Int
  size::NTuple{N,Int}
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

function SliceCube(c::AbstractCubeData{T,N},ax,i) where {T,N}
  axlist = axes(c)
  iax = findAxis(ax,c)
  iax<1 && error("Axis $ax not found in input cube")
  i = axVal2Index(axlist[iax],i,fuzzy=true)
  0<i<=length(axlist[iax]) || error("Axis index $i out of bounds")
  axlistnew = deleteat!(copy(axlist),iax)
  pnew=copy(c.properties)
  pnew[axname(axlist[iax])]=axlist[iax].values[i]
  SliceCube{T,N-1,iax}(c,i,ntuple(i->length(axlistnew[i]),N-1),axlistnew,pnew)
end

Base.size(x::SliceCube)=x.size
Base.size(x::SliceCube,i)=x.size[i]
axes(v::SliceCube)=v.cubeAxes
getCubeDes(v::SliceCube)=getCubeDes(v.parent)
using Base.Cartesian
@generated function _read(x::SliceCube{T,N,F},thedata::Tuple,r::CartesianIndices{N}) where {T,N,F}
  iax = F
  startinds = Expr(:tuple,insert!(Any[:(rstart[$i]) for i=1:N],iax,:(x.ival))...)
  stopinds  = Expr(:tuple,insert!(Any[:(rstop[$i]) for i=1:N],iax,:(x.ival))...)
  newsize   = Expr(:tuple,insert!(Any[:(sout[$i]) for i=1:N],iax,1)...)
  quote
    aout,mout=thedata
    sout = size(aout)
    newsize = $newsize
    aout2,mout2 = reshape(aout,newsize), reshape(mout,newsize)
    rstart = r.start
    rstop  = r.stop
    rnew   = CartesianRange(CartesianIndex($startinds),CartesianIndex($stopinds))
    _read(x.parent, (aout2,mout2), rnew)
    return aout,mout
  end
end


gethandle(c::SliceCube,block_size)=gethandle(c,block_size,handletype(c.parent))
@generated function gethandle(c::SliceCube{T,N,F},block_size,::ViewHandle) where {T,N,F}
  iax = F
  v1 = Expr(:call,:view,:data,insert!(Any[:(:) for i=1:N],iax,:(c.ival))...)
  v2 = Expr(:call,:view,:mask,insert!(Any[:(:) for i=1:N],iax,:(c.ival))...)
  quote
    data,mask = gethandle(c.parent)
    ($v1,$v2)
  end
end
gethandle(c::SliceCube,block_size,::CacheHandle) = getcachehandle(c,CartesianIndex(block_size))
