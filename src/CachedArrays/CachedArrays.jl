module CachedArrays
export CachedArray, getSubRange
using Base.Cartesian

abstract CacheBlock{T,N}
type SimpleCacheBlock{T,N} <: CacheBlock{T,N}
    data::Array{T,N}
    score::Float64
    position::CartesianIndex{N}
end
emptyblock{T,N}(b::Type{SimpleCacheBlock{T,N}})=SimpleCacheBlock{T,N}(Array(T,ntuple(i->0,N)),0.0,CartesianIndex{N}()-CartesianIndex{N}())
zeroblock{T,N}(b::Type{SimpleCacheBlock{T,N}},block_size,position)=SimpleCacheBlock{T,N}(zeros(T,block_size.I),0.0,position)
getValues(b::SimpleCacheBlock,I...)=b.data[I...]
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
getValues(b::MaskedCacheBlock,I::Union{Integer,UnitRange}...)=(sub(b.data,I...),sub(b.mask,I...))
getValues(b::MaskedCacheBlock,I::Integer...)=(b.data[I...],b.mask[I...])
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

function getBlockIndEx(N,isym,iIsym,bIsym)
    isym_d=symbol(string(isym,"_d"))
    iIsym_d=symbol(string(iIsym,"_d"))
    bIsym_d=symbol(string(bIsym,"_d"))
    quote
      @nexprs $N d->($(bIsym_d)=div($(isym_d)-1,c.block_size[d]))
      @nexprs $N d->($(iIsym_d)=$(isym_d)-$(bIsym_d)*c.block_size[d])
      @nexprs $N d->($(bIsym_d) = $(bIsym_d)+1)
    end
end

function getBlockExchangeEx(N)
    quote
        blockx,i = findmin(c.currentblocks)
        c.blocks[blockx.position]=c.emptyblock
        blockx.position=CartesianIndex(@ntuple($N,bI))
        @nref($N,blocks,bI)=blockx
        read_subblock!(blockx,c.x,c.block_size,CartesianIndex(@ntuple($N,bI)))
    end
end

function findminscore(c::CachedArray)
    todel,i=findmin(c.currentblocks)
end


hi=Expr(:call,:(Base.getindex{T}),:(c::CachedArray{T,N}))
hiRange=Expr(:call,:(getSubRange{T,S<:MaskedCacheBlock}),:(c::CachedArray{T,N,S}))
higetVal=Expr(:call,:getValues,:blockx)
higetSub=Expr(:call,:getSubRange,:c)
ex=5
for N=1:5
    push!(higetVal.args,symbol("iI_$N"))
    push!(higetSub.args,:($(symbol("iL_$N"))-1+$(symbol("istart_$N"))))
  # This is the function body that first determines the subblock to read,
  # then check if this is in cache and returns the value. bI refers to the index of the
  # block and iI refers to the index inside the block
  funcbody=quote
    $(getBlockIndEx(N,"i","iI","bI"))
    blocks=c.blocks
    if @nref($N,blocks,bI) == c.emptyblock
      $(getBlockExchangeEx(N))
    else
      blockx=@nref($N,blocks,bI)
    end
    blockx.score+=1.0
    d=blockx.data
    return @nref $N d iI
  end
  #Here is the function body if getindex is called on ranges.
  funcbodyRange=quote
    @nexprs $N d->(istart_d=i_d[1];iend_d=i_d[end])
    $(getBlockIndEx(N,"istart","iIstart","bIstart"))
    $(getBlockIndEx(N,"iend","iIend","bIend"))
    blocks=c.blocks
    if @nall $N d->(bIstart_d==bIend_d)
        @nexprs $N d->(bI_d=bIstart_d)
        if @nref($N,blocks,bI) == c.emptyblock
            $(getBlockExchangeEx(N))
        else
            blockx=@nref($N,blocks,bI)
        end
        blockx.score+=1.0
        @nexprs $N d->(iI_d = iIstart_d==iIend_d ? iIstart_d : iIstart_d:iIend_d)
        return $higetVal
    else
        outsize = @ntuple $N d->(iend_d-istart_d+1)
        outar   = zeros(T,outsize)
        maskout = zeros(UInt8,outsize)
        @nloops $N iL outar d->(begin
            val,mask = $higetSub
            @nref($N,outar,iL)=val[1]
            @nref($N,maskout,iL)=mask[1]
        end)
        return outar,maskout
    end
  end
  hi.args[2].args[2].args[3]=N
  hiRange.args[2].args[2].args[3]=N
  push!(hi.args,:($(symbol(string("i_",N)))::Integer))
  push!(hiRange.args,:($(symbol(string("i_",N)))::Union{UnitRange,Integer}))
  ex=Expr(:function,hi,funcbody)
  exRange=Expr(:function,hiRange,funcbodyRange)
  eval(ex)
  eval(exRange)
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
import CABLAB.CubeAPI.SubCubeV
function read_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::SubCube{T},block_size::CartesianIndex{N},i::CartesianIndex{N})
    istart = (i-CartesianIndex{N}()).*block_size
    sx,sy,sz=size(y)
    _read(y,x.data,x.mask,xoffs=istart[1],yoffs=istart[2],toffs=istart[3],nx=min(sx,block_size[1]),ny=min(sy,block_size[2]),nt=min(sz,block_size[3]))
end

function read_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::SubCubeV{T},block_size::CartesianIndex{N},i::CartesianIndex{N})
    istart = (i-CartesianIndex{N}()).*block_size
    sx,sy,sz,nvar=size(y)
    _read(y,x.data,x.mask,xoffs=istart[1],yoffs=istart[2],toffs=istart[3],nx=min(sx,block_size[1]),ny=min(sy,block_size[2]),nt=min(sz,block_size[3]),voffs=istart[4],nv=min(sz,block_size[4]))
end



end # module
