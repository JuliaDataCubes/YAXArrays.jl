import OnlineStats: OnlineStat, fit!, value
import IterTools
import WeightedOnlineStats
import WeightedOnlineStats: WeightedOnlineStat
abstract type TableAggregator end
struct OnlineAggregator{O,S}<:TableAggregator
    o::O
end
function OnlineAggregator(O::Type{<:OnlineStat},s::Symbol) where N
    os = O()
    OnlineAggregator{typeof(os),s}(os)
end
cubeeltype(t::OnlineAggregator)=Float64
function fitrow!(o::OnlineAggregator{T,S},r) where {T<:OnlineStat,S}
    v = getproperty(r,S)
    !ismissing(v) && fit!(o.o,v)
end
value(o::OnlineAggregator)=value(o.o)
struct WeightOnlineAggregator{O,S,W}<:TableAggregator
    o::O
    w::W
end
function WeightOnlineAggregator(O::Type{<:WeightedOnlineStat},s::Symbol,w) where N
    os = O()
    WeightOnlineAggregator{typeof(os),s,typeof(w)}(os,w)
end
cubeeltype(t::WeightOnlineAggregator{T}) where T = cubeeltype(T)
value(o::WeightOnlineAggregator)=value(o.o)
function fitrow!(o::WeightOnlineAggregator{T,S},r) where {T<:OnlineStat,S}
    v = getproperty(r,S)
    w = o.w(r)
    if !ismissing(v) && !ismissing(w)
      fit!(o.o,v,w)
    end
end
struct GroupedOnlineAggregator{O,S,BY,W,C}<:TableAggregator
    d::O
    w::W
    by::BY
end
value(o::GroupedOnlineAggregator)=Dict(zip(keys(o.d),map(value,(values(o.d)))))
unmiss(::Type{Union{T,Missing}}) where T = T
unmiss(T)=T
struct SymType{S}
end
SymType(s::Symbol)=SymType{s}()
(f::SymType{S})(x) where S=getproperty(x,S)
import WeightedOnlineStats: WeightedCovMatrix
getbytypes(et,by) = Tuple{map(i->unmiss(Base.return_types(i,Tuple{et})[1]),by)...}
cubeeltype(t::GroupedOnlineAggregator{T}) where T=cubeeltype(T)
cubeeltype(t::Type{<:Dict{<:Any,T}}) where T = cubeeltype(T)
cubeeltype(t::Type{<:WeightedOnlineStat{T}}) where T = T
cubeeltype(t::Type{<:WeightedCovMatrix{T}}) where T = T


function GroupedOnlineAggregator(O::Type{<:WeightedOnlineStat},s::Symbol,by,w,iter) where N
    ost = typeof(O())
    et = eltype(iter)
    bytypes = Tuple{map(i->unmiss(Base.return_types(i,Tuple{et})[1]),by)...}
    d = Dict{bytypes,ost}()
    GroupedOnlineAggregator{typeof(d),s,typeof(by),typeof(w),O}(d,w,by)
end

dicteltype(::Type{<:Dict{K,V}}) where {K,V} = V
dictktype(::Type{<:Dict{K,V}}) where {K,V} = K
function fitrow!(o::GroupedOnlineAggregator{T,S,BY,W,C},r) where {T,S,BY,W,C}
    v = getproperty(r,S)
    if !ismissing(v)
        w = o.w(r)
        if w==nothing
            bykey = map(i->i(r),o.by)
            if !any(ismissing,bykey)
                if haskey(o.d,bykey)
                    fit!(o.d[bykey],v)
                else
                    o.d[bykey] = C()
                    fit!(o.d[bykey],v)
                end
            end
        else
           if !ismissing(w)
                bykey = map(i->i(r),o.by)
                if !any(ismissing,bykey)
                    if haskey(o.d,bykey)
                        fit!(o.d[bykey],v,w)
                    else
                        o.d[bykey] = C()
                        fit!(o.d[bykey],v,w)
                    end
                end
            end
        end
    end
end
export TableAggregator, fittable
function TableAggregator(iter,O::Type{<:OnlineStat},fitsym;by=(),weight=nothing)
    if !isempty(by)
        weight==nothing && (weight=(i->nothing))
        by = map(i->isa(i,Symbol) ? (SymType(i)) : i,by)
        GroupedOnlineAggregator(O,fitsym,by,weight,iter)
    else
        if weight==nothing
            OnlineAggregator(O,fitsym)
        else
            WeightOnlineAggregator(O,fitsym,weight)
        end
    end
end

function tooutaxis(::SymType{s},iter::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,S},k,ibc) where {s,S}
    ichosen = findfirst(i->i===s,fieldnames(S))
    if ichosen<=length(iter.inars)
        bycube = iter.dc.incubes[ichosen].cube
        if haskey(bycube.properties,"labels")
            idict=bycube.properties["labels"]
            axname=get(bycube.properties,"name","Label")
            outAxis=CategoricalAxis(axname,collect(String,values(idict)))
            convertdict=Dict(k=>i for (i,k) in enumerate(keys(idict)))
        else
            sort!(k)
            outAxis=CategoricalAxis("Label$(ibc)",k)
            convertdict=Dict(k=>i for (i,k) in enumerate(k))
        end
    else
       iax = findAxis(string(s),iter.dc.LoopAxes)
        outAxis=iter.dc.LoopAxes[iax]
        convertdict=Dict(k=>i for (i,k) in enumerate(outAxis.values))
    end
    outAxis,convertdict
end
function tooutaxis(f,iter::CubeIterator{<:Any,<:Any,<:Any,<:Any,<:Any,S},k,ibc) where S
    sort!(k)
    outAxis=CategoricalAxis("Category$(ibc)",k)
    convertdict=Dict(k=>i for (i,k) in enumerate(k))
    outAxis,convertdict
end

varsym(::WeightOnlineAggregator{<:Any,S}) where S = S
varsym(::OnlineAggregator{<:Any,S}) where S = S
varsym(::GroupedOnlineAggregator{<:Any,S}) where S = S
axt(::CategoricalAxis)=CategoricalAxis
axt(::RangeAxis)=RangeAxis
getStatType(::WeightOnlineAggregator{T}) where T = T
getStatType(::OnlineAggregator{T}) where T = T
getStatType(t::GroupedOnlineAggregator{T}) where T=getStatType(T)
getStatType(t::Type{<:Dict{<:Any,T}}) where T = T

getStatOutAxes(tab,agg)=getStatOutAxes(tab,agg,getStatType(agg))
getStatOutAxes(tab,agg,::Type{<:OnlineStat})=()
function getStatOutAxes(tab,agg,::Type{<:WeightedCovMatrix})
    nvar = length(fieldnames(eltype(tab)))
    ax = getAxis(String(varsym(agg)),collect(tab.loopaxes))
    oldname = ESDL.Cubes.Axes.axname(ax)
    coname = string("Co",oldname)
    v = ax.values
    axtype = axt(ax)
    a1 = axtype(oldname,copy(v))
    a2 = axtype(coname,copy(v))
    (a1,a2)
end
function getByAxes(iter,agg::GroupedOnlineAggregator)
    by = agg.by
    ntuple(length(by)) do ibc
      bc=agg.by[ibc]
      tooutaxis(bc,iter,unique(map(i->i[ibc],collect(keys(agg.d)))),ibc)
    end
end
getByAxes(iter,agg)=()

function tooutcube(
    agg,
    iter
  )
  outaxby = getByAxes(iter,agg)
  axby = map(i->i[1],outaxby)
  convdictall = map(i->i[2],outaxby)

  outaxstat = getStatOutAxes(iter,agg)
  outax = (outaxstat...,axby...)
  snew = map(length,outax)
  aout = zeros(cubeeltype(agg),snew)
  mout = fill(0x01,snew)

  filloutar(aout,mout,convdictall,agg,map(i->1:length(i),outaxstat))

  CubeMem(collect(CubeAxis,outax),aout,mout)
end
function filloutar(aout,mout,convdictall,agg::GroupedOnlineAggregator,s)
    for (k,v) in agg.d
        i = CartesianIndices((s...,map((i,d)->d[i]:d[i],k,convdictall)...))
        aout[i.indices...].=value(v)
        mout[i.indices...].=0x00
    end
end
function filloutar(aout,mout,convdictall,agg,g)
    aout[:]=value(agg.o)
    fill!(mout,0x00)
end
"""
    fittable(tab,o::Type{<:OnlineStat},fitsym;by=(),weight=nothing)

Loops through an iterable table `tab` and thereby fitting an OnlineStat `o` with the values
specified through `fitsym`. Optionally one can specify a field (or tuple) to group by.
Any groupby specifier can either be a symbol denoting the entry to group by or an anynymous
function calculating the group from a table row.

For example the following would caluclate a weighted mean over a cube weighted by grid cell
area and grouped by country and month

````julia
fittable(iter,WeightedMean,:tair,weight=(i->cosd(i.lat)),by=(i->month(i.time),:country))
````
"""
function fittable(tab,o::Type{<:OnlineStat},fitsym;by=(),weight=nothing)
  agg = TableAggregator(tab,o,fitsym,by=by,weight=weight)
  foreach(i->fitrow!(agg,i),tab)
  tooutcube(agg,tab)
end

struct collectedValue{V,S,SY}
    value::V
    laststruct::S
end

function Base.getproperty(s::collectedValue{<:Any,<:Any,SY},sy::Symbol) where SY
    if sy == SY
        getfield(s,:value)
    else
        getproperty(getfield(s,:laststruct),sy)
    end
end

function collectval(row::Union{Tuple, Vector},::Val{SY}) where SY
    nvars = length(row)
    v = ntuple(i->getfield(row[i],SY),nvars) |> collect
    val = collectedValue{typeof(v),typeof(row[end]),SY}(v, row[end])
end

function fittable(
  tab,
  o::Type{<:WeightedOnlineStat{WeightedOnlineStats.VectorOb}},
  fitsym;
  by=(),
  weight=nothing
  )
  nvars = length(getAxis(string(fitsym),collect(tab.loopaxes)))
  tab2 = IterTools.partition(tab, nvars) |>
  x -> IterTools.imap(a->collectval(a,Val(fitsym)), x)
  agg = TableAggregator(tab2, o, fitsym, by=by, weight=weight)
  foreach(i -> fitrow!(agg,i), tab2)
  tooutcube(agg, tab)
end
