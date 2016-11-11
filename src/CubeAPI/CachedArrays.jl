module CachedArrays
importall ..Cubes
importall ..Cubes.TempCubes
import ..Cubes.TempCubes.tofilename
export CachedArray, MaskedCacheBlock, getSubRange, getSubRange2
importall ..CubeAPI
importall ..CABLABTools
using Base.Cartesian

abstract CacheBlock{T,N}
type SimpleCacheBlock{T,N} <: CacheBlock{T,N}
    data::Array{T,N}
    score::Float64
    position::CartesianIndex{N}
    iswritten::Bool
end
emptyblock{T,N}(b::Type{SimpleCacheBlock{T,N}})=SimpleCacheBlock{T,N}(Array(T,ntuple(i->0,N)),0.0,CartesianIndex{N}()-CartesianIndex{N}(),false)
zeroblock{T,N}(b::Type{SimpleCacheBlock{T,N}},block_size,position)=SimpleCacheBlock{T,N}(zeros(T,block_size.I),0.0,position,false)
getValues(b::SimpleCacheBlock,I...)=view(b.data,I...)
import Base.<
<(c1::CacheBlock,c2::CacheBlock)=c1.score<c2.score

type MaskedCacheBlock{T,N} <: CacheBlock{T,N}
    data::Array{T,N}
    mask::Array{UInt8,N}
    score::Float64
    position::CartesianIndex{N}
    iswritten::Bool
end
emptyblock{T,N}(b::Type{MaskedCacheBlock{T,N}})=MaskedCacheBlock{T,N}(Array(T,ntuple(i->0,N)),Array(UInt8,ntuple(i->0,N)),0.0,CartesianIndex{N}()-CartesianIndex{N}(),false)
zeroblock{T,N}(b::Type{MaskedCacheBlock{T,N}},block_size,position)=MaskedCacheBlock{T,N}(zeros(T,block_size.I),zeros(UInt8,block_size.I),0.0,position,false)
getValues(b::MaskedCacheBlock,I::Union{Integer,UnitRange,Colon}...)=(view(b.data,I...),view(b.mask,I...))
#getValues(b::MaskedCacheBlock,I::Integer...)=(b.data[I...],b.mask[I...])
function setValues(b::MaskedCacheBlock,vals,mask,I::Union{Integer,UnitRange,Colon}...)
    b.data[I...]=vals
    b.mask[I...]=mask
end
function setValues(b::MaskedCacheBlock,vals,mask,I::Integer...)
    b.data[I...]=vals[1]
    b.mask[I...]=mask[1]
end

type CachedArray{T,N,B,S}<:AbstractArray{T,N}
    x::S
    max_blocks::Int
    block_size::CartesianIndex{N}
    blocks::Array{B,N}
    currentblocks::Vector{B}
    emptyblock::B
end

import Base.show
function show(io::IO,s::MIME"text/plain",x::CachedArray)
  println(io,"Cached Array with cache size $(x.block_size.I) around the following Array:")
  show(io,s,x.x)
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
            read_subblock!(newblock,x,block_size)
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
    isym_d=Symbol(string(isym,"_d"))
    iIsym_d=Symbol(string(iIsym,"_d"))
    bIsym_d=Symbol(string(bIsym,"_d"))
    quote
      @nexprs $N d->($(bIsym_d) = div($(isym_d)-1,block_size[d]))
      @nexprs $N d->(offs_d     = $(bIsym_d)*block_size[d])
      @nexprs $N d->($(iIsym_d) = $(isym_d)-offs_d)
      @nexprs $N d->($(bIsym_d) = $(bIsym_d)+1)
    end
end

function getBlockExchangeEx(N)
    quote
        blockx,i = findmin(c.currentblocks)
        blockx.iswritten && write_subblock!(blockx,c.x,block_size)
        c.blocks[blockx.position]=c.emptyblock
        blockx.position=CartesianIndex(@ntuple($N,bI))
        @nref($N,blocks,bI)=blockx
        read_subblock!(blockx,c.x,block_size)
    end
end

function slowgetRangeEx(N,higetVal,higetSub)
    if higetSub.args[1]==:getSubRange
        return quote
            outsize = @ntuple $N d->(iend_d-istart_d+1)
            outar   = zeros(T,outsize)
            maskout = zeros(UInt8,outsize)
            @nloops $N iL outar (begin
                val,mask = $higetSub
                @nref($N,outar,iL)=val[1]
                @nref($N,maskout,iL)=mask[1]
            end)
            return outar,maskout
        end
    else
        return quote
            outsize = @ntuple $N d->(iend_d-istart_d+1)
            @nloops $N iL i->1:outsize[i] (begin
                $higetSub
            end)
        end
    end
end

setWriteEx(e::Expr)=e.args[1]==:setSubRange ? :(blockx.iswritten=true) : :()
@inline firstval(x::Integer)=x
@inline firstval(x::UnitRange)=x.start
@inline firstval(x::Colon)=1
@inline llength(x,s)=length(x)
@inline llength(x::Colon,s)=s
@inline subOffs(x,o)=x-o
@inline subOffs(x::Colon,o)=x


function funcbodyRangeEx(N,higetVal,higetSub)
    quote
      block_size=c.block_size
      @nexprs $N d->(istart_d=firstval(i_d);l_d=llength(i_d,size(c,d)))
      $(getBlockIndEx(N,"istart","iIstart","bI"))
      blocks=c.blocks
      if @nall $N d->(iIstart_d+l_d-1<=block_size[d])
          if @nref($N,blocks,bI) == c.emptyblock
              $(getBlockExchangeEx(N))
          else
              blockx=@nref($N,blocks,bI)
          end
          blockx.score+=1.0
          @nexprs $N d->(iI_d = subOffs(i_d,offs_d))
          o=$higetVal
          blockx.iswritten=write
          return o
      else
          #$(slowgetRangeEx(N,higetVal,higetSub))
          error("trying to access subrange at wrong indices")
      end
    end
end


function getSubRange2(x...;kwargs...)
  a,m=getSubRange(x...;kwargs...)
  return toAr(a),toAr(m)
end
function toAr{T<:Number,N}(a::SubArray{T,N})
  Base.iscontiguous(a) || error("Array is not cont")
  unsafe_wrap(Array{T,N},pointer(a),size(a))
end
toAr(a)=a
toAr{T<:Number}(a::SubArray{T,0})=unsafe_wrap(Array{T,0},pointer(a),size(a))


function findminscore(c::CachedArray)
    todel,i=findmin(c.currentblocks)
end

@generated function getSingVal{N}(c::CachedArray,bI::NTuple{N,Integer},iI::NTuple{N,Integer})
    sEx1=Expr(:ref,:(@nref($N,blocks,d->bI[d]).data),[:(iI[$i]) for i=1:N]...)
    sEx2=Expr(:ref,:(@nref($N,blocks,d->bI[d]).mask),[:(iI[$i]) for i=1:N]...)
    quote
        blocks=c.blocks
        if @nref($N,blocks,d->bI[d]) == c.emptyblock
            blockx,i = findmin(c.currentblocks)
            blockx.iswritten && write_subblock!(blockx,c.x,block_size)
            blocks[blockx.position]=c.emptyblock
            blockx.position=CartesianIndex{N}(bI)
            @nref($N,blocks,d->bI[d])=blockx
            read_subblock!(blockx,c.x,c.block_size)
        end
        ($sEx1,$sEx2)
    end
end

missval(::Float64)=NaN64
missval(::Float32)=NaN32
missval{T<:Integer}(::T)=typemax(T)

function Base.getindex(c::CachedArray,i::Integer...)
  v,m = getSingVal(c,i...)
  if (m & MISSVAL) == MISSVAL
    return missval(v)
  else
    return v
  end
end 

hi2=Expr(:call,:(getSingVal{T}),:(c::CachedArray{T,N}))
hiRange=Expr(:call,:(getSubRange{T,S<:CacheBlock}),Expr(:parameters,Expr(:kw,:write,false)),:(c::CachedArray{T,N,S}))
hisetRange=Expr(:call,:(setSubRange{T,S<:MaskedCacheBlock}),Expr(:parameters,Expr(:kw,:write,false)),:(c::CachedArray{T,N,S}),:vals,:mask)
hisetRange=Expr(:call,:(setSubRange{T,S<:SimpleCacheBlock}),Expr(:parameters,Expr(:kw,:write,false)),:(c::CachedArray{T,N,S}),:vals)
higetVal=Expr(:call,:getValues,:blockx)
hisetVal=Expr(:call,:setValues,:blockx,:vals,:mask)
higetSub=Expr(:call,:getSubRange,:c)
hisetSub=Expr(:call,:setSubRange,:c,:vals,:mask)
ex=5
for N=1:5
  push!(higetVal.args,Symbol("iI_$N"))
  push!(higetSub.args,:($(Symbol("iL_$N"))-1+$(Symbol("istart_$N"))))
  push!(hisetVal.args,Symbol("iI_$N"))
  push!(hisetSub.args,:($(Symbol("iL_$N"))-1+$(Symbol("istart_$N"))))
  # This is the function body that first determines the subblock to read,
  # then check if this is in cache and returns the value. bI refers to the index of the
  # block and iI refers to the index inside the block
  funcbody2=quote
    block_size=c.block_size
    $(getBlockIndEx(N,"i","iI","bI"))
    blocks=c.blocks
    if @nref($N,blocks,bI) == c.emptyblock
      $(getBlockExchangeEx(N))
    else
      blockx=@nref($N,blocks,bI)
    end
    blockx.score+=1.0
    d=blockx.data
    m=blockx.mask
    return (@nref($N,d,iI),@nref($N,m,iI))
  end
  funcbodyRange=funcbodyRangeEx(N,higetVal,higetSub)
  funcbodyRangeSet=funcbodyRangeEx(N,hisetVal,hisetSub)
  #Here is the function body if getindex is called on ranges.
  hi2.args[2].args[2].args[3]=N
  hiRange.args[3].args[2].args[3]=N
  hisetRange.args[3].args[2].args[3]=N
  push!(hi2.args,:($(Symbol(string("i_",N)))::Integer))
  push!(hiRange.args,:($(Symbol(string("i_",N)))::Union{UnitRange,Integer,Colon}))
  push!(hisetRange.args,:($(Symbol(string("i_",N)))::Union{UnitRange,Integer,Colon}))
  ex2=Expr(:function,hi2,funcbody2)
  exRange=Expr(:function,hiRange,funcbodyRange)
  exsetRange=Expr(:function,hisetRange,funcbodyRangeSet)
  eval(ex2)
  eval(exRange)
  eval(exsetRange)
end


using NetCDF


function read_subblock!{T,N}(x::CacheBlock{T,N},y::Array{T,N},block_size::CartesianIndex{N})
    istart = CItimes((x.position-CartesianIndex{N}()),block_size)
    ysmall = view(y,asRanges(istart+CartesianIndex{N}(),block_size))
    copy!(x.data,ysmall)
end

function write_subblock!{T,N}(x::CacheBlock{T,N},y::Array{T,N},block_size::CartesianIndex{N})
    istart = CItimes((x.position-CartesianIndex{N}()),block_size)
    ysmall = view(y,asRanges(istart+CartesianIndex{N}(),block_size))
    copy!(ysmall,x.data)
    x.iswritten=false
end

function read_subblock!{T,N}(x::SimpleCacheBlock{T,N},y::NcVar{T,N},block_size::CartesianIndex{N})
    istart = CItimes((x.position-CartesianIndex{N}()),block_size)
    NetCDF.readvar!(y,x.data,asRanges(istart+CartesianIndex{N}(),block_size)...)
end

import CABLAB.CubeAPI.SubCube, CABLAB.CubeAPI.SubCubePerm
import CABLAB.CubeAPI._read
import CABLAB.CubeAPI.SubCubeV, CABLAB.CubeAPI.SubCubeVPerm

toSymbol(d::DataType)=Symbol(split(replace(string(d),r"\{\S*\}",""),".")[end])

function read_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::AbstractCubeData{T},block_size::CartesianIndex{N})
    r = CartesianRange(CItimes((x.position-CartesianIndex{N}()),block_size)+CartesianIndex{N}(),CItimes((x.position),block_size))
    _read(y,(x.data,x.mask),r)
end

function read_subblock!{T,N}(x::SimpleCacheBlock{T,N},y::AbstractCubeData{T},block_size::CartesianIndex{N})
    r = CartesianRange(CItimes((x.position-CartesianIndex{N}()),block_size)+CartesianIndex{N}(),CItimes((x.position),block_size))
    _read(y,x.data,r)
end

write_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::Any,block_size::CartesianIndex{N},i::CartesianIndex{N})=error("$(typeof(y)) is not writeable. Please add a write_subblock method.")

function write_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::TempCube{T,N},block_size::CartesianIndex{N})
    filename=joinpath(y.folder,tofilename(x.position))
    #println("Writing to file $filename")
    ncwrite(x.data,filename,"cube")
    ncwrite(x.mask,filename,"mask")
    ncclose(filename)
    x.iswritten=false
end
function read_subblock!{T,N}(x::MaskedCacheBlock{T,N},y::TempCube{T,N},block_size::CartesianIndex{N})
    if block_size==y.block_size
        filename=joinpath(y.folder,tofilename(x.position))
        #println("Reading from file $filename")
        ncread!(filename,"cube",x.data)
        ncread!(filename,"mask",x.mask)
        ncclose(filename)
    else
        r = CartesianRange(CItimes((x.position-CartesianIndex{N}()),block_size)+CartesianIndex{N}(),CItimes((x.position),block_size))
        _read(y,(x.data,x.mask),r)
    end
end

function sync(c::CachedArray)
    for b in c.currentblocks
        if b.iswritten
            write_subblock!(b,c.x,c.block_size)
        end
    end
end


sync(c)=1


end # module
