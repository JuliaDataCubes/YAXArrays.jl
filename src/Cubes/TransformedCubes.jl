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
function _read(x::PermCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  perm=x.perm
  iperm=getiperm(perm)
  r2=CartesianIndices((permtuple(r.indices,iperm)))
  sr = size(r2)
  aout = MaskArray(zeros(T,sr...),zeros(UInt8,sr...))
  _read(x.parent,aout,r2)
  permutedims!(thedata.data,aout.data,perm)
  permutedims!(thedata.mask,aout.mask,perm)

end
Base.permutedims(x::AbstractCubeData{T,N},perm) where {T,N}=PermCube{T,N,typeof(x)}(x,perm)
function gethandle(c::PermCube,block_size)
  handle = gethandle(c.parent)
  PermutedDimsArray(handle,c.perm)
end

import Base.Iterators.product

# mutable struct MergedAxisCube{T,N,C} <: AbstractCubeData{T,N}
#   parent::C
#   imerge::Int
#   newAxes::Vector{CubeAxis}
# end
# getCubeDes(v::MergedAxisCube)=getCubeDes(v.parent)
# function caxes(v::MergedAxisCube)
#   v.newAxes
# end
# cubeproperties(v::MergedAxisCube)=cubeproperties(v.parent)
# iscompressed(c::MergedAxisCube)=iscompressed(c.parent)
# #TODO implement proper chunk function for merged axes
# #Also the order of the merged axes needs to be completely different to be efficient
#
# Base.size(x::MergedAxisCube)=ntuple(i->length(x.newAxes[i]),ndims(x))
# Base.size(x::MergedAxisCube,i)=length(x.newAxes[i])
# function _read(x::MergedAxisCube{T,N},thedata::Tuple{Any,Any},r::CartesianIndices{N}) where {T,N}
#
#   s1,s2 = size(x.parent)[x.imerge:x.imerge+1]
#   sr = r.indices[x.imerge]
#
#   aout,mout = thedata
#   saout=size(aout)
#   if length(sr)==1
#         sr2 = ind2sub((s1,s2),first(sr))
#         aout2 = reshape(aout,saout[1:x.imerge-1]...,1,1,saout[x.imerge+1:end]...)
#         mout2 = reshape(mout,saout[1:x.imerge-1]...,1,1,saout[x.imerge+1:end]...)
#         r2 = CartesianIndices(r.indices[1:x.imerg-1]...,sr2[1],sr2[2],r.indices[x.imerge+1:end]...)
#         _read(x.parent,(aout2,mout2),r2)
#   elseif sr[2]-sr[1]==size(x,x.imerge)-1
#         aout2 = reshape(aout,saout[1:x.imerge-1]...,s1,s2,saout[x.imerge+1:end]...)
#         mout2 = reshape(mout,saout[1:x.imerge-1]...,s1,s2,saout[x.imerge+1:end]...)
#         r2 = CartesianIndices(r.indices[1:x.imerge-1]...,1:s1,1:s2,r.indices[x.imerge+1:end]...)
#     _read(x.parent,(aout2,mout2),r2)
#   else
#     error("Cropping into mergedaxiscubes not yet possible")
#   end
# end
#
# function gethandle(c::MergedAxisCube,block_size)
#   data,mask = gethandle(c.parent)
#   s = size(data)
#   reshape(data,s[1:c.imerge-1]...,s[c.imerge]*s[c.imerge+1],s[c.imerge+2:end]...), reshape(mask,s[1:c.imerge-1]...,s[c.imerge]*s[c.imerge+1],s[c.imerge+2:end]...)
# end
#
# function mergeAxes(c::AbstractCubeData,a1,a2)
#     i1=findAxis(a1,c)
#     i2=findAxis(a2,c)
#     abs(i1-i2)==1 || error("Can only merge axes that are consecutive in cube")
#     ax = caxes(c)
#     imerge=min(i1,i2)
#     a1 = ax[imerge]
#     a2 = ax[imerge+1]
#     newAx = CategoricalAxis(string(axname(a1),"_x_",axname(a2)),product(a1.values,a2.values))
#     MergedAxisCube{eltype(c),ndims(c)-1,typeof(c)}(c,min(i1,i2),[ax[1:imerge-1];newAx;ax[imerge+2:end]])
# end


mutable struct TransformedCube{T,N,F} <: AbstractCubeData{T,N}
  parents
  op::F
  cubeAxes::Vector{CubeAxis}
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
caxes(v::TransformedCube)=v.cubeAxes
getCubeDes(v::TransformedCube)="Transformed cube $(getCubeDes(v.parents[1]))"
iscompressed(v::TransformedCube)=any(iscompressed,v.parents)
cubechunks(v::TransformedCube)=cubechunks(v.parents[1])
chunkoffset(v::TransformedCube)=chunkoffset(v.parents[1])


using Base.Cartesian
function _read(x::TransformedCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  ainter=map(x.parents) do c
    aouti=MaskArray(Array{eltype(c)}(undef,size(aout)), zeros(UInt8,size(mout)))
    _read(c,aouti,r)
    aouti
  end
  datas = map(i->i.data,ainter)
  masks = map(i->i.mask,ainter)
  map!(x.op,thedata.data,datas...)
  map!((x...)->reduce(|,x),thedata.mask,masks...)
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
  axlist=copy(caxes(cl[1]))
  T=eltype(cl[1])
  N=ndims(cl[1])
  for i=2:length(cl)
    all(caxes(cl[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    eltype(cl[i])==T || error("All cubes must have the same element type, cube number $i does not match")
    ndims(cl[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(cl)...)
  ConcatCube{T,N+1}(cl,catAxis,axlist,props)
end
Base.size(x::ConcatCube)=(size(x.cubelist[1])...,length(x.catAxis))
Base.size(x::ConcatCube{T,N},i) where {T,N}=i==N ? length(x.catAxis) : size(x.cubelist[1],i)
caxes(v::ConcatCube)=[v.cubeAxes;v.catAxis]
iscompressed(x::ConcatCube)=any(iscompressed,x.cubelist)
cubechunks(x::ConcatCube)=(cubechunks(x.cubelist[1])...,1)
chunkoffset(x::ConcatCube)=(chunkoffset(x.cubelist[1])...,0)
getCubeDes(v::ConcatCube)="Collection of $(getCubeDes(v.cubelist[1]))"
using Base.Cartesian
@generated function _read(x::ConcatCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  viewEx1=Expr(:call,:view,:aout,fill(Colon(),N-1)...,:j)
  quote
    aout=thedata
    rnew = CartesianIndices(r.indices[1:end-1])
    for (j,i)=enumerate(r.indices[end])
      a=$viewEx1
      _read(x.cubelist[i],a,rnew)
    end
    return aout
  end
end

using RecursiveArrayTools
function gethandle(c::ConcatCube,block_size)
  VectorOfArray(map(gethandle,c.cubelist))
end

export SliceCube
mutable struct SliceCube{T,N,iax} <: AbstractCubeData{T,N}
  parent
  ival::Int
  size::NTuple{N,Int}
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

function SliceCube(c::AbstractCubeData{T,N},ax,i) where {T,N}
  axlist = caxes(c)
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
caxes(v::SliceCube)=v.cubeAxes
getCubeDes(v::SliceCube)=getCubeDes(v.parent)
iscompressed(v::SliceCube)=iscomporessed(v.parent)
cubechunks(v::SliceCube{T,N,F}) where {T,N,F} = cubechunks(v.parent)[[1:F-1;F+1:end]]
chunkoffset(v::SliceCube{T,N,F}) where {T,N,F} = chunkoffset(v.parent)[[1:F-1;F+1:end]]

using Base.Cartesian
@generated function _read(x::SliceCube{T,N,F},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N,F}
  iax = F
  newinds = Expr(:tuple,insert!(Any[:(r.indices[$i]) for i=1:N],iax,:(x.ival:x.ival))...)
  newsize   = Expr(:tuple,insert!(Any[:(sout[$i]) for i=1:N],iax,1)...)
  quote
    sout = size(thedata)
    newsize = $newsize
    aout2 = reshape(thedata,newsize)
    rnew   = CartesianIndices($newinds)
    _read(x.parent, aout2, rnew)
    return thedata
  end
end


@generated function gethandle(c::SliceCube{T,N,F},block_size) where {T,N,F}
  iax = F
  v1 = Expr(:call,:view,:a,insert!(Any[:(:) for i=1:N],iax,:(c.ival))...)
  quote
    a = gethandle(c.parent)
    $v1
  end
end
