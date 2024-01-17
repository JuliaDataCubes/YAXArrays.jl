import OnlineStats: OnlineStat, Extrema, fit!, value, HistogramStat, Ash
import IterTools
using WeightedOnlineStats
using Distributed: nworkers
using ParallelUtilities: pmapreduce
import ProgressMeter: next!, Progress, ProgressUnknown

import WeightedOnlineStats: WeightedOnlineStat
abstract type TableAggregator end
struct OnlineAggregator{O,S} <: TableAggregator
    o::O
end
function OnlineAggregator(O::OnlineStat, s::Symbol)
    OnlineAggregator{typeof(O),s}(copy(O))
end
cubeeltype(t::OnlineAggregator) = Float64
function Base.merge!(t1::OnlineAggregator,t2::OnlineAggregator)
    merge!(t1.o,t2.o)
    t1
end
function fitrow!(o::OnlineAggregator{T,S}, r) where {T<:OnlineStat,S}
    v = getproperty(r, S)
    !ismissing(v) && fit!(o.o, v)
end
value(o::OnlineAggregator) = value(o.o)
struct WeightOnlineAggregator{O,S,W} <: TableAggregator
    o::O
    w::W
end
function WeightOnlineAggregator(O::WeightedOnlineStat, s::Symbol, w)
    WeightOnlineAggregator{typeof(O),s,typeof(w)}(copy(O), w)
end
cubeeltype(t::WeightOnlineAggregator{T}) where {T} = cubeeltype(T)
value(o::WeightOnlineAggregator) = value(o.o)
function fitrow!(o::WeightOnlineAggregator{T,S}, r) where {T<:OnlineStat,S}
    v = getproperty(r, S)
    w = o.w(r)
    if !checkmiss(v) && !ismissing(w)
        fit!(o.o, v, w)
    end
end
function Base.merge!(t1::WeightOnlineAggregator, t2::WeightOnlineAggregator)
    merge!(t1.o,t2.o)
    t1
end
checkmiss(v) = ismissing(v)
checkmiss(v::AbstractVector) = any(ismissing, v)
struct GroupedOnlineAggregator{O,S,BY,W,C} <: TableAggregator
    d::O
    w::W
    by::BY
    cloneobj::C
end
value(o::GroupedOnlineAggregator) = Dict(zip(keys(o.d), map(value, (values(o.d)))))
struct SymType{S} end
SymType(s::Symbol) = SymType{s}()
(f::SymType{S})(x) where {S} = getproperty(x, S)
getbytypes(et, by) =
    Tuple{map(i -> Base.nonmissingtype(Base.return_types(i, Tuple{et})[1]), by)...}
cubeeltype(t::GroupedOnlineAggregator{T}) where {T} = cubeeltype(T)
cubeeltype(t::Type{<:Dict{<:Any,T}}) where {T} = cubeeltype(T)
cubeeltype(t::Type{<:WeightedOnlineStat{T}}) where {T} = T
cubeeltype(t::Type{<:OnlineStat{<:Number}}) = Float64
cubeeltype(t::Type{<:WeightedCovMatrix{T}}) where {T} = T
cubeeltype(t::Type{<:Extrema{T}}) where {T} = T


function GroupedOnlineAggregator(O::OnlineStat, s::Symbol, by, w, iter)
    ost = typeof(O)
    et = eltype(iter)
    bytypes =
        Tuple{map(i -> Base.nonmissingtype(Base.return_types(i, Tuple{et})[1]), by)...}
    d = Dict{bytypes,ost}()
    GroupedOnlineAggregator{typeof(d),s,typeof(by),typeof(w),ost}(d, w, by, O)
end

dicteltype(::Type{<:Dict{K,V}}) where {K,V} = V
dictktype(::Type{<:Dict{K,V}}) where {K,V} = K
function fitrow!(o::GroupedOnlineAggregator{T,S,BY,W}, r) where {T,S,BY,W}
    v = getproperty(r, S)
    if !ismissing(v)
        w = o.w(r)
        if w===nothing
            bykey = map(i->i(r),o.by)
            if !any(ismissing,bykey)
                if haskey(o.d,bykey)
                    fit!(o.d[bykey],v)
                else
                    o.d[bykey] = copy(o.cloneobj)
                    fit!(o.d[bykey],v)
                end
            end
        else
            if !ismissing(w)
                bykey = map(i -> i(r), o.by)
                if !any(ismissing, bykey)
                    if haskey(o.d, bykey)
                        fit!(o.d[bykey], v, w)
                    else
                        o.d[bykey] = copy(o.cloneobj)
                        fit!(o.d[bykey], v, w)
                    end
                end
            end
        end
    end
end
function Base.merge!(t1::GroupedOnlineAggregator, t2::GroupedOnlineAggregator)
    merge!(merge!,t1.d,t2.d)
    t1
end

export TableAggregator, fittable, cubefittable
function TableAggregator(iter, O, fitsym; by = (), weight = nothing)
    !isa(by, Tuple) && (by = (by,))
    if !isempty(by)
        weight === nothing && (weight = (i -> nothing))
        by = map(i -> isa(i, Symbol) ? (SymType(i)) : i, by)
        GroupedOnlineAggregator(O, fitsym, by, weight, iter)
    else
        if weight === nothing
            OnlineAggregator(O, fitsym)
        else
            WeightOnlineAggregator(O, fitsym, weight)
        end
    end
end

function tooutaxis(
    ::SymType{s},
    iter::CubeIterator,
    k,
    ibc,
) where {s}
    ichosen = findfirst(i -> i === s, iter.schema.names)
    if ichosen <= length(iter.dc.incubes)
        bycube = iter.dc.incubes[ichosen].cube
        if haskey(bycube.properties, "labels")
            idict = bycube.properties["labels"]
            axname = get(bycube.properties, "name", "Label")
            outAxis = DD.rebuild(DD.key2dim(Symbol(axname)), collect(String, values(idict)))
            convertdict = Dict(k => i for (i, k) in enumerate(keys(idict)))
        else
            sort!(k)
            outAxis = DD.rebuild(DD.key2dim(Symbol(s)), k)
            convertdict = Dict(k => i for (i, k) in enumerate(k))
        end
    else
        iax = findAxis(string(s), iter.dc.LoopAxes)
        outAxis = iter.dc.LoopAxes[iax]
        convertdict = Dict(k => i for (i, k) in enumerate(DD.LookupArrays.val(outAxis)))
    end
    outAxis, convertdict
end
function tooutaxis(f, iter::CubeIterator, k, ibc)
    sort!(k)
    outAxis = DD.rebuild(DD.key2dim(Symbol("Category$(ibc)")), k)
    convertdict = Dict(k => i for (i, k) in enumerate(k))
    outAxis, convertdict
end

varsym(::WeightOnlineAggregator{<:Any,S}) where {S} = S
varsym(::OnlineAggregator{<:Any,S}) where {S} = S
varsym(::GroupedOnlineAggregator{<:Any,S}) where {S} = S
#axt(::CategoricalAxis) = CategoricalAxis
#axt(::RangeAxis) = RangeAxis
getStatType(::WeightOnlineAggregator{T}) where {T} = T
getStatType(::OnlineAggregator{T}) where {T} = T
getStatType(t::GroupedOnlineAggregator{T}) where {T} = getStatType(T)
getStatType(t::Type{<:Dict{<:Any,T}}) where {T} = T

getStatOutAxes(tab, agg) = getStatOutAxes(tab, agg, getStatType(agg))
getStatOutAxes(tab, agg, ::Type{<:OnlineStat}) = ()
function getStatOutAxes(tab, agg, ::Type{<:Extrema})
    (DD.rebuild(DD.key2dim(:Extrema), ["min", "max"]),)
end
function getStatOutAxes(tab, agg, ::Type{<:WeightedCovMatrix})
    varn = tab.schema.names
    s = varsym(agg)
    icube = findfirst(isequal(s), varn)
    ax = tab.dc.incubes[icube].axesSmall[1]
    oldname = DD.name(ax)
    coname = string("Co", oldname)
    v = ax.val
    a1 = DD.Dim{oldname}(copy(v))
    a2 = DD.Dim{Symbol(coname)}(copy(v))
    (a1, a2)
end
function getStatOutAxes(tab,agg,::Type{<:Union{Ash,HistogramStat, WeightedAdaptiveHist}})
    nbin = getnbins(agg)
    a1 = DD.rebuild(DD.key2dim(Symbol("Bin")), 1:nbin)
    a2 = DD.rebuild(DD.key2dim(Symbol("Hist")), ["MidPoints", "Frequency"])
    (a1, a2)
end
function getByAxes(iter, agg::GroupedOnlineAggregator)
    by = agg.by
    ntuple(length(by)) do ibc
        bc = agg.by[ibc]
        tooutaxis(bc, iter, unique(map(i -> i[ibc], collect(keys(agg.d)))), ibc)
    end
end
getByAxes(iter, agg) = ()

function tooutcube(agg, iter, post)
    outaxby = getByAxes(iter, agg)
    axby = map(i -> i[1], outaxby)
    convdictall = map(i -> i[2], outaxby)

    outaxstat = getStatOutAxes(iter, agg)
    outax = (outaxstat..., axby...)
    snew = map(length, outax)
    aout = fill!(zeros(Union{cubeeltype(agg),Missing}, snew), missing)
    filloutar(aout, convdictall, agg, map(i -> 1:length(i), outaxstat), post)
    YAXArray(outax, aout)
end
function filloutar(aout, convdictall, agg::GroupedOnlineAggregator, s, post)
    for (k, v) in agg.d
        i = CartesianIndices((
            s...,
            map(
                (i, d) -> d[convert(keytype(d), i)]:d[convert(keytype(d), i)],
                k,
                convdictall,
            )...,
        ))
        aout[i.indices...] .= post(v)
    end
end
function filloutar(aout, convdictall, agg, g, post)
    copyto!(aout, post(agg.o))
end
"""
    fittable(tab,o,fitsym;by=(),weight=nothing)

Loops through an iterable table `tab` and thereby fitting an OnlineStat `o` with the values
specified through `fitsym`. Optionally one can specify a field (or tuple) to group by.
Any groupby specifier can either be a symbol denoting the entry to group by or an anynymous
function calculating the group from a table row.

For example the following would caluclate a weighted mean over a cube weighted by grid cell
area and grouped by country and month:

````julia
fittable(iter,WeightedMean,:tair,weight=(i->abs(cosd(i.lat))),by=(i->month(i.time),:country))
````
"""
function fittable(tab::CubeIterator, o, fitsym; by = (), weight = nothing, showprog = false)
    func = nworkers() > 1 ? pmapreduce : mapreduce
    func(merge!,tab) do t
        agg = TableAggregator(t, o, fitsym, by = by, weight = weight)
        foreach(i -> fitrow!(agg, i), Tables.rows(t))
        GC.gc()
        agg
    end
end
fittable(tab::CubeIterator, o::Type{<:OnlineStat}, fitsym; kwargs...) =
    fittable(tab, o(), fitsym; kwargs...)

getmeter(tab) = getmeter(Base.IteratorSize(tab), tab)
getmeter(::Union{Base.HasLength,Base.HasShape}, tab) = Progress(length(tab))
getmeter(::Base.SizeUnknown, tab) = ProgressUnknown("Rows processed: ")

@noinline function runfitrows_progress(agg, tab)
    p = getmeter(tab)
    every = 0
    for row in tab
        fitrow!(agg, row)
        every += 1
        if every == 100
            next!(p, step = 100)
            every = 0
        end
    end
end

struct collectedValue{V,S,SY}
    value::V
    laststruct::S
end

function Base.getproperty(s::collectedValue{<:Any,<:Any,SY}, sy::Symbol) where {SY}
    if sy == SY
        getfield(s, :value)
    else
        getproperty(getfield(s, :laststruct), sy)
    end
end

function collectval(row::Union{Tuple,Vector}, ::Val{SY}) where {SY}
    nvars = length(row)
    v = ntuple(i -> getfield(row[i], SY), nvars) |> collect
    val = collectedValue{typeof(v),typeof(row[end]),SY}(v, row[end])
end

getpostfunction(s::OnlineStat) = getpostfunction(typeof(s))
getpostfunction(::Type{<:OnlineStat}) = value
function getpostfunction(hist::Union{Ash, HistogramStat, WeightedAdaptiveHist})
    nb = getnbins(hist)
    i->begin
        r = hcat(value(i)...)
        if size(r,1)<nb
            r = vcat(r,zeros(eltype(r),nb-size(r,1),2))
        end
        r
    end
end
getnbins(f::GroupedOnlineAggregator) = getnbins(f.cloneobj)
getnbins(f::TableAggregator) = getnbins(f.o)
getnbins(histogram::HistogramStat) = histogram.k
getnbins(whist::WeightedAdaptiveHist) = whist.alg.b
getnbins(a::Ash) = length(a.density)

fitfun(o) = fitfun(typeof(o))
fitfun(::Type{<:Any}) = fittable

"""
    cubefittable(tab,o,fitsym;post=getpostfunction(o),kwargs...)

Executes [`fittable`](@ref) on the [`CubeTable`](@ref) `tab` with the
(Weighted-)OnlineStat `o`, looping through the values specified by `fitsym`.
Finally, writes the results from the `TableAggregator` to an output data cube.
"""
function cubefittable(tab, o, fitsym; post = getpostfunction(o), kwargs...)
    agg = fitfun(o)(tab, o, fitsym; showprog = true, kwargs...)
    tooutcube(agg, tab, post)
end

function tupleeltypebyname(::Type{NamedTuple{names,tt}}, s::Symbol) where {names,tt}
    i = findfirst(isequal(s), names)
    fieldtype(tt, i)
end
