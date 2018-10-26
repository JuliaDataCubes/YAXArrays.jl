struct PickAxisArray{P,N}
  parent::P
  stride::NTuple{N,Int}
end
function PickAxisArray(p,indmask)
  @show indmask
  @show ndims(p)
  @assert sum(indmask) == ndims(p)
  strides = zeros(Int,length(indmask))
  s = 1
  j = 1
  for i=1:length(indmask)
    if indmask[i]
      strides[i]=s
      s = s * size(p,j)
      j=j+1
    else
      strides[i]=0
    end
  end
  pstrides = ntuple(i->strides[i],length(strides))
  PickAxisArray{typeof(p),length(strides)}(p,pstrides)
end
function Base.getindex(a::PickAxisArray{P,N},i::Vararg{Int,N}) where {P,N}
    ilin = sum(map((i,s)->(i-1)*s,i,a.stride))+1
    a.parent[ilin]
end
function Base.getindex(a::PickAxisArray{P,N},i::NTuple{N,Int}) where {P,N}
    ilin = sum(map((i,s)->(i-1)*s,i,a.stride))+1
    a.parent[ilin]
end
Base.getindex(a::PickAxisArray,i::CartesianIndex) = a[i.I]

import ESDL.DAT: DATConfig
import ESDL.CubeAPI.Mask: MaskArray
struct CubeIterator{R,ART,ARTBC,LAX,ILAX,RN,RT}
    dc::DATConfig
    r::R
    inars::ART
    inarsBC::ARTBC
    loopaxes::LAX
end
Base.IteratorSize(::Type{<:CubeIterator})=Base.HasLength()
Base.IteratorEltype(::Type{<:CubeIterator})=Base.HasEltype()
Base.eltype(i::Type{<:CubeIterator{A,B,C,D,E,F,G}}) where {A,B,C,D,E,F,G} = NamedTuple{F,G}
# function cubeeltypes(::Type{<:CubeIterator{<:Any,ART}}) where ART
#   allt = gettupletypes.(gettupletypes(ART))
#   map(i->eltype(i[1]),allt)
# end
# gettupletypes(::Type{Tuple{A}}) where A = (A,)
# gettupletypes(::Type{Tuple{A,B}}) where {A,B} = (A,B)
# gettupletypes(::Type{Tuple{A,B,C}}) where {A,B,C} = (A,B,C)
# gettupletypes(::Type{Tuple{A,B,C,D}}) where {A,B,C,D} = (A,B,C,D)
# gettupletypes(::Type{Tuple{A,B,C,D,E}}) where {A,B,C,D,E} = (A,B,C,D,E)
# gettupletypes(::Type{Tuple{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = (A,B,C,D,E,F)
# axtypes(::Type{<:CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = axtype.(gettupletypes(D))
# axtype(::Type{<:CubeAxis{T}}) where T = T
# getrownames(::Type{<:CubeIterator{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = F
# getncubes(::Type{<:CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = gettuplelen(B)
axsym(ax::CubeAxis{<:Any,S}) where S = S
# gettuplelen(::Type{<:NTuple{N,Any}}) where N = N
@noinline function CubeIterator(dc,r;varnames::Tuple=ntuple(i->Symbol("x$i"),length(dc.incubes)),include_loopvars=true)
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
    length(varnames) == length(dc.incubes) || error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    if include_loopvars
      varnames = (map(axsym,loopaxes)...,varnames...)
      ilax = ntuple(i->i,length(loopaxes))
    else
      ilax = ()
    end
    lopi = falses(length(loopaxes))
    foreach(ilax) do il
      lopi[il]=true
    end
    rt = map(c->Union{eltype(c.handle[1]),Missing},dc.incubes)
    laxt = map(ax->eltype(ax),loopaxes[lopi])
    inarsbc = map(dc.incubes) do ic
      allax = falses(length(dc.LoopAxes))
      allax[ic.loopinds].=true
      PickAxisArray(MaskArray(ic.handle...),allax)
    end
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),ilax,varnames,Tuple{laxt...,rt...}}(dc,r,inars,inarsbc,loopaxes)
end
function Base.show(io::IO,ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,E}) where E
  print(io,"Datacube iterator with ", length(ci), " elements with fields: ",E)
end
Base.length(ci::CubeIterator)=prod(length.(ci.loopaxes))
function Base.iterate(ci::CubeIterator)
    rnow,blockstate = iterate(ci.r)
    updateinars(ci.dc,rnow)
    innerinds = CartesianIndices(length.(rnow))
    indnow, innerstate = iterate(innerinds)
    getrow(ci,ci.inarsBC,indnow),(rnow=rnow,blockstate=blockstate,innerinds = innerinds, innerstate=innerstate)
end
function Base.iterate(ci::CubeIterator,s)
    t1 = iterate(s.innerinds,s.innerstate)
    if t1 == nothing
        t2 = iterate(ci.r,s.blockstate)
        if t2 == nothing
            return nothing
        else
            rnow, blockstate = t2
            updateinars(ci.dc,rnow)
            innerinds = CartesianIndices(length.(rnow))
            indnow,innerstate = iterate(innerinds)
        end
    else
        rnow, blockstate = s.rnow, s.blockstate
        innerinds = s.innerinds
        indnow, innerstate = iterate(innerinds,s.innerstate)
    end
    getrow(ci,ci.inarsBC,indnow),(rnow=rnow,blockstate=blockstate, innerinds=innerinds, innerstate=innerstate)
end
function getrow(ci::CubeIterator{R,ART,ARTBC,LAX,ILAX,RN,RT},inarsBC,indnow) where {R,ART,ARTBC,LAX,ILAX,RN,RT}
  axvals = map(i->ci.loopaxes[i].values[indnow.I[i]],ILAX)
  cvals  = map(i->i[indnow],inarsBC)
  NamedTuple{RN,RT}((axvals...,cvals...))
end
# @generated function getrow(ci::CI,inarsBC,indnow) where CI
#     rn = getrownames(CI)
#     nc = getncubes(CI)
#     exlist = [:($(rn[i]) = inarsBC[$ir][indnow]) for (ir,i) = enumerate((length(rn)-nc+1):length(rn))]
#     if length(rn)>nc
#       exlist2 = [:($(rn[i]) = ci.loopaxes[$i].values[indnow.I[$i]]) for i=1:(length(rn)-nc)]
#       exlist = [exlist2;exlist]
#     end
#     Expr(:tuple,exlist...)
# end

export CubeTable
function CubeTable(c::AbstractCubeData...;include_axes=true)
  indims = map(i->InDims(),c)
  configiter = mapCube(identity,c,debug=true,indims=indims,outdims=());
  r = distributeLoopRanges(totuple(configiter.loopCacheSize),totuple(map(length,configiter.LoopAxes)),getchunkoffsets(configiter))
  ci = CubeIterator(configiter,r, include_loopvars=include_axes)
end


import Tables
Tables.istable(::Type{<:CubeIterator}) = true
Tables.rowaccess(::Type{<:CubeIterator}) = true
Tables.rows(x::CubeIterator) = x
Tables.schema(x::CubeIterator) = Tables.schema(typeof(x))
Tables.schema(x::Type{<:CubeIterator}) = Tables.Schema(getrownames(x),(axtypes(x)...,cubeeltypes(x)...))
