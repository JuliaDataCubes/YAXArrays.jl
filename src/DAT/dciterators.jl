struct PickAxisArray{P,N}
  parent::P
  stride::NTuple{N,Int}
end
function PickAxisArray(p,indmask)
  #@show indmask
  #@show ndims(p)
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
struct CubeIterator{R,ART,ARTBC,LAX,ILAX,S}
    dc::DATConfig
    r::R
    inars::ART
    inarsBC::ARTBC
    loopaxes::LAX
end
Base.IteratorSize(::Type{<:CubeIterator})=Base.HasLength()
Base.IteratorEltype(::Type{<:CubeIterator})=Base.HasEltype()
Base.eltype(i::Type{<:CubeIterator{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = F
# function cubeeltypes(::Type{<:CubeIterator{<:Any,ART}}) where ART
#   allt = gettupletypes.(gettupletypes(ART))
#   map(i->Union{eltype(i[1]),Missing},allt)
# end
# gettupletypes(::Type{Tuple{A}}) where A = (A,)
# gettupletypes(::Type{Tuple{A,B}}) where {A,B} = (A,B)
# gettupletypes(::Type{Tuple{A,B,C}}) where {A,B,C} = (A,B,C)
# gettupletypes(::Type{Tuple{A,B,C,D}}) where {A,B,C,D} = (A,B,C,D)
# gettupletypes(::Type{Tuple{A,B,C,D,E}}) where {A,B,C,D,E} = (A,B,C,D,E)
# gettupletypes(::Type{Tuple{A,B,C,D,E,F}}) where {A,B,C,D,E,F} = (A,B,C,D,E,F)
# axtypes(::Type{<:CubeIterator{A,B,C,D,E}}) where {A,B,C,D,E} = axtype.(gettupletypes(D))
# axtype(::Type{<:CubeAxis{T}}) where T = T
getrownames(t::Type{<:CubeIterator}) = fieldnames(t)
getncubes(::Type{<:CubeIterator{A,B}}) where {A,B} = tuplelen(B)
tuplelen(::Type{<:NTuple{N,<:Any}}) where N=N
axsym(ax::CubeAxis{<:Any,S}) where S = S

lift64(::Type{Float32})=Float64
lift64(::Type{Int32})=Int64
lift64(T)=T

function CubeIterator(s,dc,r;varnames::Tuple=ntuple(i->Symbol("x$i"),length(dc.incubes)),include_loopvars=())
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
    length(varnames) == length(dc.incubes) || error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    rt = map(c->Union{eltype(c.handle[1]),Missing},dc.incubes)
    inarsbc = map(dc.incubes) do ic
      allax = falses(length(dc.LoopAxes))
      allax[ic.loopinds].=true
      PickAxisArray(MaskArray(ic.handle...),allax)
    end
    et = map(i->Union{lift64(eltype(i[1])),Missing},inars)
    if !isempty(include_loopvars)
      ilax = map(i->findAxis(i,collect(loopaxes)),include_loopvars)
      any(isequal(nothing),ilax) && error("Axis not found in cubes")
      et=(et...,map(i->eltype(loopaxes[i]),ilax)...)
    end
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),ilax,s{et...}}(dc,r,inars,inarsbc,loopaxes)
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
    N = tuplelen(eltype(ci.r))
    if t1 == nothing
        t2 = iterate(ci.r,s.blockstate)
        if t2 == nothing
            return nothing
        else
            rnow = t2[1]
            blockstate = t2[2]
            updateinars(ci.dc,rnow)
            innerinds = CartesianIndices(length.(rnow))
            indnow,innerstate = iterate(innerinds)
        end
    else
        rnow, blockstate = s.rnow, s.blockstate
        innerinds = s.innerinds
        indnow, innerstate = iterate(innerinds,s.innerstate)
    end
    getrow(ci,ci.inarsBC,indnow),(rnow=rnow::NTuple{N,UnitRange{Int64}},
      blockstate=blockstate::Int64,
      innerinds=innerinds::CartesianIndices{N,NTuple{N,Base.OneTo{Int64}}},
      innerstate=innerstate::CartesianIndex{N})
end
abstract type CubeRow
end
#Base.getproperty(s::CubeRow,v::Symbol)=Base.getfield(s,v)
abstract type CubeRowAx<:CubeRow
end
# function Base.getproperty(s::T,v::Symbol) where T<:CubeRowAx
#   if v in fieldnames(T)
#     getfield(s,v)
#   else
#     ax = getfield(s,:axes)
#     ind = getfield(s,:i)
#     i = findfirst(i->axsym(i)==v,ax)
#     ax[i].values[ind.I[i]]
#   end
# end

# @noinline function getrow(ci::CubeIterator{R,ART,ARTBC,LAX,ILAX,RN,RT},inarsBC,indnow)::NamedTuple{RN,RT} where {R,ART,ARTBC,LAX,ILAX,RN,RT}
#   axvals = map(i->ci.loopaxes[i].values[indnow.I[i]],ILAX)
#   cvals  = map(i->i[indnow],inarsBC)
#   allvals::RT = (axvals...,cvals...)
#   #NamedTuple{RN,RT}(axvals...,cvals...)
#   NamedTuple{RN,RT}(allvals)
# end
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,ILAX,S},inarsBC,indnow) where {ILAX,S<:CubeRowAx}
   inds = map(i->indnow.I[i],ILAX)
   #axvals = map((i,indnow)->ci.loopaxes[i][indnow],ILAX,inds)
   axvalsall = map((ax,i)->ax.values[i],ci.loopaxes,indnow.I)
   axvals = map(i->axvalsall[i],ILAX)
   cvals  = map(i->i[indnow],inarsBC)
   S(cvals...,axvals...)
end
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,S},inarsBC,indnow) where S<:CubeRow
   cvals  = map(i->i[indnow],inarsBC)
   S(cvals...)
end

# @generated function getrow(ci::CI,inarsBC,indnow) where CI
#     rn = getrownames(CI)
#     nc = getncubes(CI)
#     exlist = [:($(rn[i]) = inarsBC[$ir][indnow]) for (ir,i) = enumerate((length(rn)-nc+1):length(rn))]
#     if length(rn)>nc
#       exlist2 = [:($(rn[i]) = ci.loopaxes[$i].values[indnow.I[$i]]) for i=1:(length(rn)-nc)]
#       exlist = [exlist2;exlist]
#     end
#     Expr(:(::),Expr(:tuple,exlist...),eltype(ci))
# end

function Base.show(io::IO,s::CubeRow)
  print(io,"Cube Row: ")
  for n in propertynames(s)
    print(io,string(n), "=",getproperty(s,n)," ")
  end
end
function Base.show(io::IO,s::CubeRowAx)
  print(io,"Cube Row: ")
  for n in propertynames(s)
    print(io,string(n), "=",getproperty(s,n)," ")
  end
end
Base.show(io::IO,s::Type{<:CubeRow})=print(io,"Cube Row with fields: ",fieldnames(s)...)
function Base.iterate(s::CubeRow,state=1)
  allnames = propertynames(s)
  if state<=length(allnames)
    (getproperty(s,allnames[state]),state+1)
  else
    nothing
  end
end


import DataStructures: OrderedDict
export CubeTable
macro CubeTable(cubes...)
  axargs=[]
  clist = OrderedDict{Any,Any}()
  for c in cubes
    if isa(c,Symbol)
      clist[esc(c)]=esc(c)
    elseif isa(c,Expr) && c.head==:(=)
      if c.args[1]==:axes
        axdef = c.args[2]
        if isa(axdef,Symbol)
          push!(axargs,axdef)
        else
          append!(axargs,axdef.args)
        end
      else
        clist[esc(c.args[1])]=esc(c.args[2])
      end
    end
  end
  allcubes = collect(values(clist))
  allnames = collect(keys(clist))
  s = esc(gensym())
  theparams = Expr(:curly,s,[Symbol("T$i") for i=1:length(clist)]...)
  fields = Expr(:block,[Expr(:(::),fn,Symbol("T$i")) for (i,fn) in enumerate(allnames)]...)
  #pn = Expr(:tuple,map(i->QuoteNode(i.args[1]),allnames)...)
  if !isempty(axargs)
    foreach(axargs) do ax
      as = Symbol(ax)
      push!(theparams.args,Symbol("AX$as"))
      push!(fields.args,:($(esc(as))::$(Symbol("AX$as"))))
      #push!(pn.args,as)
    end
    supert=:CubeRowAx
  else
    supert=:CubeRow
  end
  quote
    struct $theparams <: $supert
      $fields
    end
    #Base.propertynames(s::$s)=$pn
    _CubeTable($s,$(allcubes...),include_axes=$(Expr(:tuple,string.(axargs)...)), varnames=$(Expr(:tuple,QuoteNode.(allnames)...)))
  end
end


function _CubeTable(thetype,c::AbstractCubeData...;include_axes=(),varnames=varnames)
  indims = map(i->InDims(),c)
  configiter = mapCube(identity,c,debug=true,indims=indims,outdims=());
  r = collect(distributeLoopRanges(totuple(configiter.loopCacheSize),totuple(map(length,configiter.LoopAxes)),getchunkoffsets(configiter)))
  ci = CubeIterator(thetype,configiter,r, include_loopvars=include_axes,varnames=varnames)
end


import Tables
Tables.istable(::Type{<:CubeIterator}) = true
Tables.rowaccess(::Type{<:CubeIterator}) = true
Tables.rows(x::CubeIterator) = x
Tables.schema(x::CubeIterator) = Tables.schema(typeof(x))
Tables.schema(x::Type{<:CubeIterator}) = Tables.Schema(getrownames(x),(axtypes(x)...,cubeeltypes(x)...))
