module Stats
export normalizeTS, timeVariance, timeMean, spatialMean
importall ..DAT
importall ..CubeAPI
importall ..Proc
importall ..Cubes
using DataArrays
using StatsBase

"""
    normalizeTS(c::AbstractCubeData)

Normalize a time series to zeros mean and unit variance

**Input Axes** `TimeAxis`

**Output Axes** `TimeAxis`
"""
function normalizeTS(c::AbstractCubeData;kwargs...)
  mapCube(normalizeTS,c;indims=InDims("Time",miss=NaNMissing()),outdims=OutDims("Time",miss=NaNMissing()),kwargs...)
end
function normalizeTS(xout::AbstractVector,xin::AbstractVector)
  xin2 = filter(i->!isnan(i),xin)
    if length(xin2)>2
        m = mean(xin2)
        s = std(xin2)
        s = s==zero(s) ? one(s) : s
        map!(x->(x-m)/s,xout,xin)
    else
        xout[:]=NaN
    end
end

# """
#     timespacequantiles(cube,quantiles)
#
# Calculate quantiles from a space time data cube. This is usually called on a subset
# of data returned by [sampleLandPoints](@ref).
#
# * `cube` data cube with a axes: `TimeAxis`, `SpatialPointAxis`
# * `quantiles` a vector of quantile values to calculate
#
# **Input Axes** `TimeAxis`, `SpatialPointAxis`
#
# **Output Axes** `QuantileAxis`
#
# Calculating exact quantiles from data that don't fit into memory is quite a problem. One solution we provide
# here is to simply subsample your data and then get the quantiles from a smaller dataset.
#
# For an example on how to apply this function, see [this notebook](https://github.com/CAB-LAB/JuliaDatDemo/blob/master/eventdetection2.ipynb).
# """
# function timespacequantiles(c::AbstractCubeData, quantiles)
#
# end
#
# function timespacequantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
#     empty!(xtest)
#     @inbounds for i=1:length(xin)
#       !isnan(xin[i]) && push!(xtest,xin[i])
#     end
#     quantile!(xout,xtest,q)
# end
#
# function timelonlatquantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
#   empty!(xtest)
#   @inbounds for i=1:length(xin)
#     !isnan(xin[i]) && push!(xtest,xin[i])
#   end
#   quantile!(xout,xtest,q)
# end
#
# import ESDL.Proc.MSC.getNpY
#
#
# registerDATFunction(timelonlatquantiles,(TimeAxis,LonAxis,LatAxis),
#   ((cube,pargs)->begin
#     length(pargs)==0 ? CategoricalAxis("Quantile",[0.25,0.5,0.75]) : CategoricalAxis("Quantile",pargs[1])
#   end,),
#   (cube,pargs)->begin
#     tax=getAxis(ByName("Time"),cube[1])
#     lonax=getAxis(ByName("Lon"),cube[1])
#     latax=getAxis(ByName("Lat"),cube[1])
#     return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1].cube),length(tax)*length(lonax)*length(latax))
#   end,inmissing=(:nan,),outmissing=:nan)
#
# registerDATFunction(timespacequantiles,(TimeAxis,SpatialPointAxis),
#   ((cube,pargs)->begin
#     length(pargs)==0 ? CategoricalAxis("Quantile",[0.25,0.5,0.75]) : CategoricalAxis("Quantile",pargs[1])
#   end,),
#   (cube,pargs)->begin
#     tax=getAxis(TimeAxis,cube[1])
#     sax=getAxis(SpatialPointAxis,cube[1])
#     return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1]),length(tax)*length(sax))
#   end,inmissing=(:nan,),outmissing=:nan)
#




end
