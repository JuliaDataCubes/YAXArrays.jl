module CachedArrays
export CachedArray
using Base.Cartesian

abstract CacheBlock{T,N}
type SimpleCacheBlock{T,N} <: CacheBlock{T,N}
    data::Array{T,N}
    score::Float64
    position::CartesianIndex{N}
end
emptyblock{T,N}(b::Type{SimpleCacheBlock{T,N}})=SimpleCacheBlock{T,N}(Array(T,ntuple(i->0,N)),0.0,CartesianIndex{N}()-CartesianIndex{N}())
zeroblock{T,N}(b::Type{SimpleCacheBlock{T,N}},block_size,position)=SimpleCacheBlock{T,N}(zeros(T,block_size.I),0.0,position)
import Base.<
<(c1::CacheBlock,c2::CacheBlock)=c1.score<c2.score

type MaskedCacheBlock{T,N} <: CacheBlock{T,N}
    data::Array{T,N}
    mask::Array{UInt8,N}
    score::Float64
    position::CartesianIndex{N}
end
emptyblock{T,N}(b::Type{MaskedCacheBlock{T,N}})=MaskedCacheBlock{T,N}(Array(T,ntuple(i->0,N)),Array(UInt8,ntuple(i->0,N)),0.0,CartesianIndex{N}()-CartesianIndex{N}())
zeroblock{T,N}(b::Type{MaskedCacheBlock{T,N}},block_size,position)=MaskedCacheBlock{T,N}(zeros(T,block_size.I),zeros(UInt8,block_size.I),0.0,position)

type CachedArray{T,N,B,S}<:AbstractArray{T,N}
    x::S
    max_blocks::Int
    block_size::CartesianIndex{N}
    blocks::Array{B,N}
    currentblocks::Vector{B}
    emptyblock::B
end

import Base: .*
@generated function Base.div{N}(index1::CartesianIndex{N}, index2::CartesianIndex{N})
    I = index1
    args = [:(Base.div(index1[$d],index2[$d])) for d = 1:N]
    :($I($(args...)))
end
@generated function .*{N}(index1::CartesianIndex{N}, index2::CartesianIndex{N})
    I = index1
    args = [:(.*(index1[$d],index2[$d])) for d = 1:N]
    :($I($(args...)))
end
@generated function asRanges{N}(start::CartesianIndex{N},count::CartesianIndex{N})
    args=[Expr(:(:),:(start.I[$i]),:(start.I[$i]+count.I[$i]-1)) for i=1:N]
    Expr(:tuple,args...)
end

function CachedArray(x,max_blocks::Int,block_size::CartesianIndex,blocktype::DataType)
    vtype=typeof(x)
    T=eltype(x)
    N=ndims(x)
    s=size(x)
    ssmall=[div(s[i],block_size[i]) for i=1:N]
    blocks=Array(blocktype,ssmall...)
    currentblocks=Array(blocktype,0)
    scores=zeros(Int64,ssmall...)
    i=1
    nullblock=emptyblock(blocktype)
    for II in CartesianRange(size(blocks))
        if i<=max_blocks
            newblock=zeroblock(blocktype,block_size,II)
            blocks[II]=newblock
            read_subblock!(newblock,x,block_size,II)
            push!(currentblocks,newblock)
        else
            blocks[II]=nullblock
        end
        i=i+1
    end
    CachedArray{T,N,blocktype,vtype}(x,max_blocks,block_size,blocks,currentblocks,nullblock)
end
Base.linearindexing(::CachedArray)=Base.LinearSlow()
Base.setindex!{T,N}(c::CachedArray{T,N},v,i::CartesianIndex{N})=0.0
Base.size(c::CachedArray)=size(c.x)
Base.similar(c::CachedArray)=similar(c.x)

function findminscore(c::CachedArray)
    todel,i=findmin(c.currentblocks)
end
hi=Expr(:call,:(Base.getindex{T}),:(c::CachedArray{T,N}))
for N=1:5
  funcbody=quote
    @nexprs $N d->(bI_d=div(i_d-1,c.block_size[d]))
    @nexprs $N d->(iI_d=i_d-bI_d*c.block_size[d])
    @nexprs $N d->(bI_d = bI_d+1)
    blocks=c.blocks
    if @nref($N,blocks,bI) == c.emptyblock
      blockx,i = findmin(c.currentblocks)
      c.blocks[blockx.position]=c.emptyblock
      blockx.position=CartesianIndex(@ntuple($N,bI))
      @nref($N,blocks,bI)=blockx
      read_subblock!(blockx,c.x,c.block_size,CartesianIndex(@ntuple($N,bI)))
      blockx.score+=1.0
      data=blockx.data
      return @nref($N,data,iI)
    else
      b=@nref($N,blocks,bI)
      b.score+=1.0
      data=b.data
      return @nref($N,data,iI)
    end
  end
  hi.args[2].args[2].args[3]=N
  push!(hi.args,symbol("i_$N"))
  ex=Expr(:function,hi,funcbody)
  eval(ex)
end


using NetCDF
function read_subblock!{T,N}(x::SimpleCacheBlock{T,N},y::Array{T,N},block_size::CartesianIndex{N},i::CartesianIndex{N})
    istart = (i-CartesianIndex{N}()).*block_size
    ysmall = sub(y,asRanges(istart+CartesianIndex{N}(),block_size))
    copy!(x.data,ysmall)
end
function read_subblock!{T,N}(x::SimpleCacheBlock{T,N},y::NcVar{T,N},block_size::CartesianIndex{N},i::CartesianIndex{N})
    istart = (i-CartesianIndex{N}()).*block_size
    NetCDF.readvar!(y,x.data,asRanges(istart+CartesianIndex{N}(),block_size)...)
end

import CABLAB.CubeAPI.SubCube
import CABLAB.CubeAPI._read
function read_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::SubCube{T},block_size::CartesianIndex{N},i::CartesianIndex{N})
    istart = (i-CartesianIndex{N}()).*block_size
    sx,sy,sz=size(y)
    _read(y,x.data,x.mask,xoffs=istart[1],yoffs=istart[2],toffs=istart[3],nx=min(sx,block_size[1]),ny=min(sy,block_size[2]),nt=min(sz,block_size[3]))
end


end # module
