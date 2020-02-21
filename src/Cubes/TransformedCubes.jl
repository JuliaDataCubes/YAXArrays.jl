export ConcatCube, concatenateCubes
export mergeAxes
import ..ESDLTools.getiperm
import ..Cubes: ESDLArray, caxes, iscompressed, cubechunks, chunkoffset
import DiskArrays: AbstractDiskArray, eachchunk, haschunks, Chunked, estimate_chunksize, GridChunks, findints, readblock!, writeblock!

function Base.permutedims(x::AbstractCubeData{T,N},perm) where {T,N}
  ESDLArray(x.axes[perm],permutedims(x.data,perm),x.properties,x.cleaner)
end

function Base.map(op, incubes::AbstractCubeData...)
  axlist=copy(caxes(incubes[1]))
  all(i->caxes(i)==axlist,incubes) || error("All axes must match")
  props=merge(cubeproperties.(incubes)...)
  ESDLArray(axlist,broadcast(op,map(c->c.data,incubes)...),props,map(i->i.cleaner,incubes))
end

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
    arnow = a.arrays[iouter]
    if isa(arnow, AbstractDiskArray)
      readblock!(a.arrays[iouter],view(aout,innercolon...,iret.I...),innerinds...)
    else
      aout[innercolon...,iret.I...] = arnow[innerinds...]
    end
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
    arnow = a.arrays[iouter]
    if isa(arnow, AbstractDiskArray)
      writeblock!(a.arrays[iouter],view(v,innercolon...,iret.I...),innerinds...)
    else
      arnow[innerinds...] = aout[innercolon...,iret.I...]
    end
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
