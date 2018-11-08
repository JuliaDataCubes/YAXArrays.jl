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
function fittable(tab,o::Type{<:OnlineStat},fitsym;by=(),weight=nothing)
  agg = TableAggregator(tab,o,fitsym,by=by,weight=weight)
  foreach(i->fitrow!(agg,i),tab)
  value(agg)
end
