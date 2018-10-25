struct PickAxisArray{P,MYINDS}
    parent::P
end
PickAxisArray(p,inds...)=PickAxisArray{typeof(p),inds}(p)
@generated function Base.getindex(a::PickAxisArray{P,MYINDS},i::Vararg{Int,N}) where {P,MYINDS,N}
    newinds = filter(i->in(i,MYINDS),1:N)
    indargs = map(i->:(i[$i]),newinds)
    return Expr(:call,:getindex,:(a.parent),indargs...)
end
Base.getindex(a::PickAxisArray,i::CartesianIndex) = a[i.I...]

import ESDL.DAT: DATConfig
import ESDL.CubeAPI.Mask: MaskArray
struct CubeIterator{R,ART,ARTBC,LAX,RN}
    dc::DATConfig
    r::R
    inars::ART
    inarsBC::ARTBC
    loopaxes::LAX
end
Base.IteratorSize(::Type{<:CubeIterator})=Base.HasLength()
Base.IteratorEltype(::Type{<:CubeIterator})=Base.HasEltype()
function Base.eltype(t::Type{<:CubeIterator})
  NamedTuple{getrownames(t),Tuple{axtypes(t)...,cubeeltypes(t)...}}
end
gettupletypes(::Type{Tuple{A}}) where A = A
gettupletypes(::Type{Tuple{A,B}}) where {A,B} = (A,B)
gettupletypes(::Type{Tuple{A,B,C}}) where {A,B,C} = (A,B,C)
gettupletypes(::Type{Tuple{A,B,C,D}}) where {A,B,C,D} = (A,B,C,D)
gettupletypes(::Type{Tuple{A,B,C,D,E}}) where {A,B,C,D,E} = (A,B,C,D,E)
gettupletypes(::Type{Tuple{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = (A,B,C,D,E,F)
axtypes(::Type{CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = axtype.(gettupletypes(D))
axtype(::Type{<:CubeAxis{T}}) where T = T
getrownames(::Type{CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = E
getncubes(::Type{CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = gettuplelen(B)
axsym(ax::CubeAxis{<:Any,S}) where S = S
gettuplelen(::Type{<:NTuple{N,Any}}) where N = N
function CubeIterator(dc,r;varnames::Tuple=ntuple(i->Symbol("x$i"),length(dc.incubes)),include_loopvars=true)
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
    length(varnames) == length(dc.incubes) || error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    if include_loopvars
      foreach(loopaxes) do lax
        varnames = (axsym(lax),varnames...)
      end
    end
    inarsbc = map(ic->PickAxisArray(MaskArray(ic.handle...),ic.loopinds...),dc.incubes)
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),varnames}(dc,r,inars,inarsbc,loopaxes)
end
function Base.show(io::IO,ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,E}) where E
  print(io,"Datacube iterator with ", length(ci), " elements with fields: ",E)
end
Base.length(ci::CubeIterator)=prod(length.(ci.loopaxes))
function Base.eltype(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,RN}) where RN
    tlist = map(i->eltype(i[1]),ci.inars)
    NamedTuple{RN,Tuple{tlist...}}
end
function Base.iterate(ci::CubeIterator)
    rnow,blockstate = iterate(ci.r)
    updateinars(ci.dc,rnow)
    innerinds = CartesianIndices(rnow)
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
            innerinds = CartesianIndices(rnow)
            indnow,innerstate = iterate(innerinds)
        end
    else
        rnow, blockstate = s.rnow, s.blockstate
        innerinds = s.innerinds
        indnow, innerstate = iterate(innerinds,s.innerstate)
    end
    getrow(ci,ci.inarsBC,indnow),(rnow=rnow,blockstate=blockstate, innerinds=innerinds, innerstate=innerstate)
end
@generated function getrow(ci::CI,inarsBC,indnow) where CI
    rn = getrownames(CI)
    nc = getncubes(CI)
    exlist = [:($(rn[i]) = inarsBC[$i][indnow]) for i = (length(rn)-nc+1):length(rn)]
    if length(rn)>nc
      exlist2 = [:($(rn[i]) = ci.loopaxes[$i].values[indnow.I[$i]]) for i=1:(length(rn)-nc)]
      exlist = [exlist2;exlist]
    end
    Expr(:tuple,exlist...)
end

export toTable
function CubeTable(c::AbstractCubeData...;include_axes=true)
  indims = map(i->InDims(),c)
  configiter = mapCube(identity,c,debug=true,indims=indims,outdims=());
  r=distributeLoopRanges(totuple(configiter.loopCacheSize),totuple(map(length,configiter.LoopAxes)),getchunkoffsets(configiter))
  ci = CubeIterator(configiter,r, include_loopvars=include_axes)
end
