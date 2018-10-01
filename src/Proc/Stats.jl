module Stats
export normalizeTS, timeVariance, timeMean, spatialMean
using ..DAT
using ..CubeAPI
using ..Proc
using ..Cubes
using StatsBase
using Statistics

"""
    normalizeTS(c::AbstractCubeData)

Normalize a time series to zeros mean and unit variance

**Input Axes** `TimeAxis`

**Output Axes** `TimeAxis`
"""
function normalizeTS(c::AbstractCubeData;kwargs...)
  mapCube(normalizeTS,c;indims=InDims("Time"),outdims=OutDims("Time"),kwargs...)
end
function normalizeTS(xout::AbstractVector,xin::AbstractVector)
  ndp = count(!ismissing,xin)
  if ndp > 2
    m = mean(skipmissing(xin))
    s = std(skipmissing(xin))
    s = s==zero(s) ? one(s) : s
    map!(x->(x-m)/s,xout,xin)
  else
    xout[:]=missing
  end
end


end
