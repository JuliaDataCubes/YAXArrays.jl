export ConcatCube, concatenateCubes
export mergeAxes
import ..ESDLTools.getiperm
import ..Cubes: ESDLArray, caxes, iscompressed, cubechunks, chunkoffset
import DiskArrays: AbstractDiskArray, eachchunk, haschunks, Chunked, estimate_chunksize, GridChunks, findints, readblock!, writeblock!

function Base.permutedims(x::AbstractCubeData{T,N},perm) where {T,N}
  ESDLArray(x.axes[perm],permutedims(x.data,perm),x.properties,Ref(true))
end

function Base.map(op, incubes::AbstractCubeData...; T::Type=eltype(incubes[1]))
  axlist=copy(caxes(incubes[1]))
  all(i->caxes(i)==axlist,incubes) || error("All axes must match")
  props=merge(cubeproperties.(incubes)...)
  ESDLArray(axlist,broadcast(op,map(c->c.data,incubes)...),props,Ref(true))
end

import DiskArrays: AbstractDiskArray
struct DiskArrayStack{T,N,M,NO}<:AbstractDiskArray{T,N}
    arrays::Array{M,NO}
end
function diskstack(a::Array{M,N}) where {N,M<:AbstractArray{T,NO}} where {T,NO}
    all(i->size(i)==size(a[1]),a) || error("All arrays in the stackl must have the same size")
    DiskArrayStack{T,N+NO,M,N}(a)
end
Base.size(r::DiskArrayStack) = (size(r.arrays[1])...,size(r.arrays)...)
haschunks(a::DiskArrayStack) = haschunks(a.arrays[1])
iscompressed(a::DiskArrayStack) = any(iscompressed,a.arrays)
function eachchunk(a::DiskArrayStack{<:Any,<:Any,<:Any,NO}) where NO
    iterold = eachchunk(a.arrays[1])
    cs = (iterold.chunksize...,ntuple(one,NO)...)
    co = (iterold.offset...,ntuple(zero,NO)...)
    DiskArrays.GridChunks(a,cs,offset=co)
end

function DiskArrays.readblock!(a::DiskArrayStack{<:Any,N,<:Any,NO},aout,i...) where {N,NO}

  innerinds = i[1:(N-NO)]

  outerinds = i[(N-NO+1):N]
  innercolon = map(_->(:), innerinds)
  iiter = CartesianIndices(outerinds)
  inum  = CartesianIndices(size(iiter))
  foreach(zip(iiter,inum)) do (iouter,iret)
    readblock!(a.arrays[iouter],view(aout,innercolon...,iret.I...),innerinds...)
  end
  nothing
end

function DiskArrays.writeblock!(a::DiskArrayStack{<:Any,N,<:Any,NO},v,i...) where {N,NO}
  innerinds = i[1:(N-NO)]

  outerinds = i[(N-NO+1):N]
  innercolon = map(_->(:), innerinds)
  iiter = CartesianIndices(outerinds)
  inum  = CartesianIndices(size(iiter))
  foreach(zip(iiter,inum)) do (iouter,iret)
    writeblock!(a.arrays[iouter],view(v,innercolon...,iret.I...),innerinds...)
  end
  nothing
end

function Base.view(a::DiskArrayStack{<:Any,N,<:Any,NO},i...) where {N,NO}
    iinner = i[1:(N-NO)]
    ashort = map(view(a.arrays,i[(N-NO+1):N]...)) do ai
        view(ai,iinner...)
    end
    if ndims(ashort)==0
      ashort[]
    else
      diskstack(ashort)
    end
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
  props=mapreduce(cubeproperties,merge,cl,init=cubeproperties(cl[1]))
  ESDLArray([axlist...,cataxis],diskstack([c.data for c in cl]),props)
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
# Base.size(x::ConcatCube)=(size(x.cubelist[1])...,length(x.cataxis))
# Base.size(x::ConcatCube{T,N},i) where {T,N}=i==N ? length(x.cataxis) : size(x.cubelist[1],i)
# caxes(v::ConcatCube)=[v.cubeaxes;v.cataxis]
# iscompressed(x::ConcatCube)=any(iscompressed,x.cubelist)
# cubechunks(x::ConcatCube)=(cubechunks(x.cubelist[1])...,1)
# chunkoffset(x::ConcatCube)=(chunkoffset(x.cubelist[1])...,0)
# getCubeDes(v::ConcatCube)="Collection of $(getCubeDes(v.cubelist[1]))"
# using Base.Cartesian
# function _read(x::ConcatCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
#   rnew = CartesianIndices(r.indices[1:end-1])
#   for (j,i)=enumerate(r.indices[end])
#     a=selectdim(thedata,N,j)
#     _read(x.cubelist[i],a,rnew)
#   end
#   return thedata
# end
# function _write(x::ConcatCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
#   rnew = CartesianIndices(r.indices[1:end-1])
#   for (j,i)=enumerate(r.indices[end])
#     a=selectdim(thedata,N,j)
#     _write(x.cubelist[i],a,rnew)
#   end
#   return nothing
# end
#
# using RecursiveArrayTools
# function gethandle(c::ConcatCube,block_size)
#   VectorOfArray(map(gethandle,c.cubelist))
# end
#
# struct SplitDimsCube{T,N,C} <: AbstractCubeData{T,N}
#     parent::C
#     newaxes
#     newchunks::Tuple{Int,Int}
#     isplit::Int
# end
#
# export splitdim
# """
# Splits an axis into two, reshaping the data cube into a higher-order cube.
# """
# function splitdim(c, dimtosplit, newdims)
#     isplit = findAxis(dimtosplit,c)
#     isplit ===nothing && error("Could not find axis in cube")
#     axesold = caxes(c)
#     length(axesold[isplit]) == prod(length.(newdims)) || error("Size of new dimensions don't match the old one")
#     all(i->isa(i,CubeAxis), newdims) || error("Newdims must be a list of cube axes")
#     splitchunk = cubechunks(c)[isplit]
#     newchunks = if splitchunk==length(newdims[1])
#         (length(newdims[1]),1)
#     elseif splitchunk>length(newdims[1])
#         iszero(rem(splitchunk,length(newdims[1]))) || error("You can not do this split since chunks woudl overlap")
#         (length(newdims[1]),splitchunk ÷ length(newdims[1]))
#     else
#         iszero(rem(length(newdims[1]),splitchunk)) || error("You can not do this split since chunks woudl overlap")
#         (length(newdims[1]) ÷ splitchunk, 1)
#     end
#     SplitDimsCube{eltype(c), ndims(c)+1, typeof(c)}(c,(newdims...,),newchunks,isplit)
# end
#
# function Base.size(x::SplitDimsCube)
#     sp = size(x.parent)
#     (sp[1:isplit-1]...,length.(newaxes)...,sp[isplit+1:end]...)
# end
# Base.size(x::SplitDimsCube{T,N},i) where {T,N} = if i<x.isplit
#     size(x.parent,i)
# elseif i==x.isplit
#     length(x.newaxes[1])
# elseif i==x.isplit+1
#     length(x.newaxes[2])
# else
#     size(x.parent,i+1)
# end
# function caxes(v::SplitDimsCube)
#     axold = caxes(v.parent)
#     [axold[1:v.isplit-1]...;v.newaxes...;axold[v.isplit+1:end]...]
# end
# getCubeDes(v::SplitDimsCube)=getCubeDes(v.parent)
# iscompressed(v::SplitDimsCube)=iscompressed(v.parent)
# function cubechunks(v::SplitDimsCube)
#     cc = cubechunks(v.parent)
#     (cc[1:v.isplit-1]...,v.newchunks...,cc[v.isplit+1:end]...)
# end
# function chunkoffset(v::SplitDimsCube)
#     co = chunkoffset(v.parent)
#     #This can not be determined, so we just assume zero here
#     (co[1:v.isplit-1]...,0,0,co[v.isplit+1:end]...)
# end
# function subsetcube(v::SplitDimsCube; kwargs...)
#     newax = collect(v.newaxes)
#     foreach(kwargs) do (k,v)
#         findAxis(k,newax) !== nothing && error("Subsetting split axes is not yet supported")
#     end
#     newcube = subsetcube(v.parent; kwargs...)
#     splitdim(newcube,caxes(newcube)[isplit],v.newaxes)
# end
# using Base.Cartesian
# function _read(x::SplitDimsCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
#   r1 = r.indices[x.isplit]
#   r2 = r.indices[x.isplit+1]
#   if length(r2)==1 && length(r1)==length(x.newaxes[1])
#     error("This read is not yet implemented")
#   end
#   istart = (first(r2)-1)*size(x,x.isplit) + first(r1)
#   iend   = (last(r2)-1) *size(x,x.isplit) + last(r1)
#   indsold = r.indices
#   inew = CartesianIndices((r.indices[1:x.isplit-1]...,istart:iend,r.indices[x.isplit+2:end]...))
#   a2 = reshape(thedata,size(inew))
#   _read(x.parent,a2,inew)
#   return thedata
# end
