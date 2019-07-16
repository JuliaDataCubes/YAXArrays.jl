struct PickAxisArray{T,N,AT<:AbstractArray,P}
    parent::AT
end

function PickAxisArray(parent, indmask)
    @assert sum(indmask)==ndims(parent)
    f  = findall(indmask)
    PickAxisArray{eltype(parent),length(indmask),typeof(parent),(f...,)}(parent)
end
indmask(p::PickAxisArray{<:Any,<:Any,<:Any,i}) where i = i
function Base.view(p::PickAxisArray, i...)
    inew = map(j->i[j],indmask(p))
    view(p.parent,inew...)
end
function Base.getindex(p::PickAxisArray, i...)
    inew = map(j->i[j],indmask(p))
    getindex(p.parent,inew...)
end
Base.getindex(p::PickAxisArray,i::CartesianIndex) = p[i.I...]

include("SentinelMissings.jl")
import .SentinelMissings
import ESDL.DAT: DATConfig
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

getrownames(t::Type{<:CubeIterator}) = fieldnames(t)
getncubes(::Type{<:CubeIterator{A,B}}) where {A,B} = tuplelen(B)
tuplelen(::Type{<:NTuple{N,<:Any}}) where N=N


lift64(::Type{Float32})=Float64
lift64(::Type{Int32})=Int64
lift64(T)=T

defaultval(t::Type{<:AbstractFloat})=convert(t,NaN)
defaultval(t::Type{<:Signed})=typemin(t)+1
defaultval(t::Type{<:Unsigned})=typemax(t)-1

function CubeIterator(dc,r;varnames::Tuple=ntuple(i->Symbol("x$i"),length(dc.incubes)),include_loopvars=())
    loopaxes = ntuple(i->dc.LoopAxes[i],length(dc.LoopAxes))
    inars = getproperty.(dc.incubes,:handle)
    length(varnames) == length(dc.incubes) || error("Supplied $(length(varnames)) varnames and $(length(dc.incubes)) cubes.")
    rt = map(c->Union{eltype(c.handle[1]),Missing},dc.incubes)
    inarsbc = map(dc.incubes) do ic
      allax = falses(length(dc.LoopAxes))
      allax[ic.loopinds].=true
      PickAxisArray(ic.handle,allax)
    end
    et = map(i->SentinelMissings.SentinelMissing{eltype(i[1]),defaultval(eltype(i[1]))},inars)
    if !isempty(include_loopvars)
      ilax = map(i->findAxis(i,collect(loopaxes)),include_loopvars)
      any(isequal(nothing),ilax) && error("Axis not found in cubes")
      et=(et...,map(i->eltype(loopaxes[i]),ilax)...)
    else
      ilax=()
    end

    elt = NamedTuple{(map(Symbol,varnames)...,map(Symbol,include_loopvars)...),Tuple{et...}}
    CubeIterator{typeof(r),typeof(inars),typeof(inarsbc),typeof(loopaxes),ilax,elt}(dc,r,inars,inarsbc,loopaxes)
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
    offs = map(i->first(i)-1,rnow)
    getrow(ci,ci.inarsBC,indnow,offs),(rnow=rnow,blockstate=blockstate,innerinds = innerinds, innerstate=innerstate)
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
    offs = map(i->first(i)-1,rnow)
    getrow(ci,ci.inarsBC,indnow,offs),(rnow=rnow::NTuple{N,UnitRange{Int64}},
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
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,ILAX,S},inarsBC,indnow,offs) where {ILAX,S}
   #inds = map(i->indnow.I[i],ILAX)
   #axvals = map((i,indnow)->ci.loopaxes[i][indnow],ILAX,inds)
   axvalsall = map((ax,i,o)->ax.values[i+o],ci.loopaxes,indnow.I,offs)
   axvals = map(i->axvalsall[i],ILAX)
   cvals  = map(i->i[indnow],inarsBC)
   S((cvals...,axvals...))
end
function getrow(ci::CubeIterator{<:Any,<:Any,<:Any,<:Any,(),S},inarsBC,indnow,offs) where S
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
function Base.show(io::IO,s::Type{<:CubeRow})
  foreach(fieldnames(s)) do fn
    print(io,fn,"::",fieldtype(s,fn),", ")
  end
end
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
"""
    CubeTable(c::AbstractCubeData...)

Function to turn a DataCube object into an iterable table. Takes a list of as arguments,
specified as a `name=cube` expression. For example
`CubeTable(data=cube1,country=cube2)` would generate a Table with the entries `data` and `country`,
where `data` contains the values of `cube1` and `country` the values of `cube2`. The cubes
are matched and broadcasted along their axes like in `mapCube`.

In addition, one can specify
`axes=(ax1,ax2...)` when one wants to include the values of certain axes in the table. For example
the command `(CubeTable(tair=cube1 axes=("lon","lat","time"))` would produce an iterator over a data structure
with entries `tair`, `lon`, `lat` and `time`.

Lastly there is an option to specify which axis shall be the fastest changing when iterating over the cube.
For example `CubeTable(tair=cube1,fastest="time"` will ensure that the iterator will always loop over consecutive
time steps of the same location.
"""
function CubeTable(;include_axes=(),fastest="",cubes...)
  inax=nothing
  c = (map((k,v)->v,keys(cubes),values(cubes))...,)
  all(i->isa(i,AbstractCubeData),c) || throw(ArgumentError("All inputs must be DataCubes"))
  varnames = map(string,keys(cubes))
  if isempty(string(fastest))
    indims = map(i->InDims(),c)
  else
    indims = map(c) do i
      iax = findAxis(string(fastest),i)
      if iax > 0
        inax = caxes(i)[iax]
        InDims(string(fastest))
      else
        InDims()
      end
    end
  end
  inaxname = inax==nothing ? nothing : axname(inax)
  axnames = map(i->axname.(caxes(i)),c)
  allvars = union(axnames...)
  allnums = collect(1:length(allvars))
  perms = map(axnames) do v
    map(i->findfirst(isequal(i),allvars),v)
  end
  c2 = map(perms,c) do p,cube
    if issorted(p)
      cube
    else
      pp=sortperm(p)
      pp = ntuple(i->pp[i],length(pp))
      permutedims(cube,pp)
    end
  end

    configiter = mapCube(identity,c2,debug=true,indims=indims,outdims=(),ispar=false);
    if inax !== nothing
    linax = length(inax)
    pushfirst!(configiter.LoopAxes,inax)
    pushfirst!(configiter.loopcachesize,linax)
    foreach(configiter.incubes) do ic1
      if !isempty(ic1.axesSmall)
        empty!(ic1.axesSmall)
        map!(i->i+1,ic1.loopinds,ic1.loopinds)
        pushfirst!(ic1.loopinds,1)
      else
        map!(i->i+1,ic1.loopinds,ic1.loopinds)
      end
    end
  end
  r = collect(distributeLoopRanges((configiter.loopcachesize...,),(map(length,configiter.LoopAxes)...,),getchunkoffsets(configiter)))
  ci = CubeIterator(configiter,r,include_loopvars=include_axes,varnames=varnames)
end

import Tables
Tables.istable(::Type{<:CubeIterator}) = true
Tables.rowaccess(::Type{<:CubeIterator}) = true
Tables.rows(x::CubeIterator) = x
Tables.schema(x::CubeIterator) = Tables.schema(typeof(x))
Tables.schema(x::Type{<:CubeIterator}) = Tables.Schema(fieldnames(eltype(x)),map(s->fieldtype(eltype(x),s),fieldnames(eltype(x))))
