module Stats
export normalizeTS, timeVariance, timeMean, spatialMean
import ..DAT: NValid
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
  println("Normalizing")
  mapCube(normalizeTS,c;indims=InDims("Time",filter=NValid(3)),outdims=OutDims("Time"),kwargs...)
end
function normalizeTS(xout::AbstractVector,xin::AbstractVector)
  m = mean(skipmissing(xin))
  s = std(skipmissing(xin))
  s = s==zero(s) ? one(s) : s
  map!(x->(x-m)/s,xout,xin)
end


end
