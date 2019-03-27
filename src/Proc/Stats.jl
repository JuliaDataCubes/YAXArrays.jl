module Stats
export normalizeTS, timeVariance, timeMean, spatialMean
import ..DAT: NValid
using ..DAT
using ..Proc
using ..Cubes
using StatsBase
using Statistics
import Statistics: quantile

"""
    normalizeTS(c::AbstractCubeData)

Normalize a time series to zeros mean and unit variance

**Input Axes** `TimeAxis`

**Output Axes** `TimeAxis`
"""
function normalizeTS(c::AbstractCubeData;kwargs...)
  mapCube(normalizeTS,c;indims=InDims("Time",filter=NValid(3)),outdims=OutDims("Time"),kwargs...)
end
function normalizeTS(xout::AbstractVector,xin::AbstractVector)
  m = mean(skipmissing(xin))
  s = std(skipmissing(xin))
  s = s==zero(s) ? one(s) : s
  map!(x->(x-m)/s,xout,xin)
end

function quantile(c::AbstractCubeData,p=[0.25,0.5,0.75];by=())
  if any(i->isa(i,CategoricalAxis{<:Any,:Hist}),caxes(c)) && any(i->isa(i,RangeAxis{<:Any,:Bin}),caxes(c))
    if isa(p,Number)
      od = OutDims()
    else
      od = OutDims(RangeAxis("Quantile",p))
    end
    mapCube(cquantile,c,p,indims=InDims("Bin","Hist"),outdims=od)
  else
    error("Please generate a cubetable and use fittable to fit a Histogram first")
  end
end

function cquantile(xout,xin,p)
  w = xin[:,2]
  nonzero = w.>0
  d = xin[nonzero,1]
  w = Float64.(xin[nonzero,2])
  xout[:] = quantile(d,pweights(w),p)
end

end
