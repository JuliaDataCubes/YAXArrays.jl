module Stats
export normalizeTS, timeVariance, timeMean, spatialMean, timespacequantiles, timelonlatquantiles
importall ..DAT
importall ..CubeAPI
importall ..Proc
importall ..Cubes
using NullableArrays
using StatsBase

"""
    normalizeTS

Normalize a time series to zeros mean and unit variance

### Call signature

    mapCube(normalizeTS, cube)

* `cube` data cube with a axes: `TimeAxis`

**Input Axes** `TimeAxis`

**Output Axes** `TimeAxis`

"""
function normalizeTS(xout::AbstractVector,xin::AbstractVector)
  m=mean(xin,skipnull=true)
  s=std(xin,skipnull=true)
  for i in eachindex(xout)
    xout[i]=(xin[i]-m)/s
  end
end

"""
    timespacequantiles

Calculate quantiles from a space time data cube. This is usually called on a subset
of data returned by [sampleLandPoints](@ref).

### Call signature

    mapCube(timespacequantiles, cube, quantiles)

* `cube` data cube with a axes: `TimeAxis`, `SpatialPointAxis`
* `quantiles` a vector of quantile values to calculate

**Input Axes** `TimeAxis`, `SpatialPointAxis`

**Output Axes** `QuantileAxis`

Calculating exact quantiles from data that don't fit into memory is quite a problem. One solution we provide
here is to simply subsample your data and then get the quantiles from a smaller dataset.

For an example on how to apply this function, see [this notebook](https://github.com/CAB-LAB/JuliaDatDemo/blob/master/eventdetection2.ipynb).
"""
function timespacequantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
    empty!(xtest)
    @inbounds for i=1:length(xin)
      !isnan(xin[i]) && push!(xtest,xin[i])
    end
    quantile!(xout,xtest,q)
end

function timelonlatquantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
  empty!(xtest)
  @inbounds for i=1:length(xin)
    !isnan(xin[i]) && push!(xtest,xin[i])
  end
  quantile!(xout,xtest,q)
end

import CABLAB.Proc.MSC.getNpY


registerDATFunction(timelonlatquantiles,(TimeAxis,LonAxis,LatAxis),
  ((cube,pargs)->begin
    length(pargs)==0 ? CategoricalAxis("Quantile",[0.25,0.5,0.75]) : CategoricalAxis("Quantile",pargs[1])
  end,),
  (cube,pargs)->begin
    tax=getAxis(TimeAxis,cube[1])
    lonax=getAxis(LonAxis,cube[1])
    latax=getAxis(LatAxis,cube[1])
    return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1]),length(tax)*length(lonax)*length(latax))
  end,inmissing=(:nan,),outmissing=:nan)

registerDATFunction(timespacequantiles,(TimeAxis,SpatialPointAxis),
  ((cube,pargs)->begin
    length(pargs)==0 ? CategoricalAxis("Quantile",[0.25,0.5,0.75]) : CategoricalAxis("Quantile",pargs[1])
  end,),
  (cube,pargs)->begin
    tax=getAxis(TimeAxis,cube[1])
    sax=getAxis(SpatialPointAxis,cube[1])
    return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1]),length(tax)*length(sax))
  end,inmissing=(:nan,),outmissing=:nan)

registerDATFunction(normalizeTS,(TimeAxis,),(TimeAxis,),inmissing=(:nullable,),outmissing=:nullable,no_ocean=1)



#Here starts the part that is copy-pasted from the NullableStats package

Base.mean(X::NullableArray; skipnull::Bool = false) =
    sum(X; skipnull = skipnull) /
        Nullable(length(X.isnull) - (skipnull * countnz(X.isnull)))

function Base.mean(X::NullableArray, w::WeightVec;
                            skipnull::Bool=false)
    if skipnull
        _X = NullableArray(X.values .* reshape(w.values,size(X)), X.isnull)
        _w = NullableArray(reshape(w.values,size(X)), X.isnull)
        return sum(_X; skipnull=true) / sum(_w; skipnull=true)
    else
        anynull(X) ? Nullable{eltype(X)}() : Nullable(mean(X.values, w))
    end
end

function Base.mean{T, W, V<:NullableArray}(X::NullableArray{T},
                                           w::WeightVec{W, V};
                                           skipnull::Bool=false)
    if skipnull
        _X = X .* w.values
        _w = NullableArray(w.values, _X.isnull)
        return sum(_X; skipnull=true) / sum(_w; skipnull=true)
    else
        anynull(X) || anynull(w) ? Nullable{T}() :
                                   Nullable(mean(X.values, w.values.values))
    end
end


function Base.varm{T}(X::NullableArray{T}, m::Number; corrected::Bool=true,
                      skipnull::Bool=false)
    if skipnull
        n = length(X)

        nnull = countnz(X.isnull)
        nnull == n && return Nullable(convert(Base.momenttype(T), NaN))
        nnull == n-1 && return Nullable(
            convert(Base.momenttype(T),
                    abs2(X.values[Base.findnextnot(X.isnull, 1)] - m)/(1 - Int(corrected))
            )
        )
        /(nnull == 0 ? Nullable(Base.centralize_sumabs2(X.values, m, 1, n)) :
                       NullableArrays.mapreduce_impl_skipnull(i->((i-m)*(i-m)),
                                               +, X),
          Nullable(n - nnull - Int(corrected))
        )
    else
        any(X.isnull) && return Nullable{T}()
        Nullable(Base.varm(X.values, m; corrected=corrected))
    end
end

function Base.varm{T, U<:Number}(X::NullableArray{T}, m::Nullable{U};
                                 corrected::Bool=true, skipnull::Bool=false)
    m.isnull && throw(NullException())
    return varm(X, m.value; corrected=corrected, skipnull=skipnull)
end

function varzm{T}(X::NullableArray{T}; corrected::Bool=true,
                       skipnull::Bool=false)
    n = length(X)
    nnull = skipnull ? countnz(X.isnull) : 0
    (n == 0 || n == nnull) && return Nullable(convert(Base.momenttype(T), NaN))
    return sumabs2(X; skipnull=skipnull) /
           Nullable((n - nnull - Int(corrected)))
end

function Base.var(X::NullableArray; corrected::Bool=true, mean=nothing,
         skipnull::Bool=false)

    (anynull(X) & !skipnull) && return Nullable{eltype(X)}()

    if mean == 0 || isequal(mean, Nullable(0))
        return Base.varzm(X; corrected=corrected, skipnull=skipnull)
    elseif mean == nothing
        return varm(X, Base.mean(X; skipnull=skipnull); corrected=corrected,
             skipnull=skipnull)
    elseif isa(mean, Union{Number, Nullable})
        return varm(X, mean; corrected=corrected, skipnull=skipnull)
    else
        error()
    end
end

function Base.stdm(X::NullableArray, m::Number;
                   corrected::Bool=true, skipnull::Bool=false)
    return sqrt(varm(X, m; corrected=corrected, skipnull=skipnull))
end

function Base.stdm{T<:Number}(X::NullableArray, m::Nullable{T};
                              corrected::Bool=true, skipnull::Bool=false)
    return sqrt(varm(X, m; corrected=corrected, skipnull=skipnull))
end

function Base.std(X::NullableArray; corrected::Bool=true,
                              mean=nothing, skipnull::Bool=false)
    return sqrt(var(X; corrected=corrected, mean=mean, skipnull=skipnull))
end



end
