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
getrownames(::Type{CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = E
function CubeIterator(dc,r;varnames=ntuple(i->Symbol("x$i"),length(dc.incubes)))
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
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
    exlist = [:($(rn[i]) = inarsBC[$i][indnow]) for i=1:length(rn)]
    Expr(:tuple,exlist...)
end

export toTable
function CubeTable(c::AbstractCubeData...)
  indims = map(i->InDims(),c)
  configiter = mapCube(identity,c,debug=true,indims=indims,outdims=());
  r=distributeLoopRanges(totuple(configiter.loopCacheSize),totuple(map(length,configiter.LoopAxes)),getchunkoffsets(configiter))
  ci = CubeIterator(configiter,r)
end
