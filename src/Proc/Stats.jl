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


end
