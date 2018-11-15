import OnlineStats: OnlineStat, fit!, value
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
cubeeltype(t::WeightOnlineAggregator{<:WeightedOnlineStat{T}}) where T=T
function WeightOnlineAggregator(O::Type{<:WeightedOnlineStat},s::Symbol,w) where N
    os = O()
    WeightOnlineAggregator{typeof(os),s,typeof(w)}(os,w)
end
value(o::WeightOnlineAggregator)=value(o.o)
function fitrow!(o::WeightOnlineAggregator{T,S},r) where {T<:OnlineStat,S}
    v = getproperty(r,S)
    w = o.w(r)
    !ismissing(v) && !ismissing(w) && fit!(o.o,v,w)
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

getbytypes(et,by) = Tuple{map(i->unmiss(Base.return_types(i,Tuple{et})[1]),by)...}
cubeeltype(t::GroupedOnlineAggregator{T}) where T=cubeeltype(T)
cubeeltype(t::Type{<:Dict{<:Any,T}}) where T = cubeeltype(T)
cubeeltype(t::Type{<:WeightedOnlineStat{T}}) where T = T

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

tooutcube(agg,iter)=CubeMem(CubeAxis[],fill(value(agg.o)),fill(0x00))
function tooutcube(agg::GroupedOnlineAggregator,iter::CubeIterator{<:Any,<:Any,<:Any,<:Any,ILAX}) where ILAX
  by=agg.by
   outax = ntuple(length(by)) do ibc
        bc=agg.by[ibc]
     tooutaxis(bc,iter,unique(map(i->i[ibc],collect(keys(agg.d)))),ibc)
   end
    snew = map(i->length(i[1]),ntuple(i->outax[i],length(outax)))
    aout = zeros(cubeeltype(agg),snew)
    mout = fill(0x01,snew)
    axall = map(i->i[1],outax)
    convdictall = map(i->i[2],outax)
    filloutar(aout,mout,convdictall,agg.d)
    CubeMem(collect(CubeAxis,axall),aout,mout)
end
function filloutar(aout,mout,convdictall,g)
    for (k,v) in g
        i = CartesianIndex(map((i,d)->d[i],k,convdictall))
        aout[i]=value(v)
        @assert mout[i]==0x01
        mout[i]=0x00
    end
end

function fittable(tab,o::Type{<:OnlineStat},fitsym;by=(),weight=nothing)
  agg = TableAggregator(tab,o,fitsym,by=by,weight=weight)
  foreach(i->fitrow!(agg,i),tab)
  tooutcube(agg,tab)
end
