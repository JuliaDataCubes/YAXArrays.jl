module Axes
export CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis,
FitAxis, SpatialPointAxis,Axes,YearStepRange,CategoricalAxis,RangeAxis,axVal2Index,MSCAxis, TimeScaleAxis, QuantileAxis, MethodAxis
import NetCDF.NcDim
import Compat.UTF8String
import Compat.ASCIIString
importall ..Cubes
using Base.Dates

immutable YearStepRange <: Range{DateTime}
    startyear::Int
    startst::Int
    stopyear::Int
    stopst::Int
    step::Int
    NPY::Int
end

function YearStepRange(start::DateTime,stop::DateTime,step::Day)
    startyear=year(start)
    startday=dayofyear(start)
    startst=ceil(Int,startday/Float64(step))
    stopyear=year(stop)
    stopday=dayofyear(stop)
    stopst=ceil(Int,stopday/Float64(step))
    NPY=ceil(Int,366/Float64(step))
    YearStepRange(startyear,startst,stopyear,stopst,Int(step),NPY)
end
function Base.length(x::YearStepRange)
    (-x.startst+1+x.stopst+(x.stopyear-x.startyear)*x.NPY)
end
Base.size(x::YearStepRange)=(length(x),)
Base.start(x::YearStepRange)=(x.startyear,x.startst)
Base.next(x::YearStepRange,st)=(DateTime(st[1])+Day((st[2]-1)*x.step),st[2]==x.NPY ? (st[1]+1,1) : (st[1],st[2]+1))
Base.done(x::YearStepRange,st)=(st[1]==x.stopyear && st[2]==x.stopst+1) || (st[1]==x.stopyear+1 && st[2]==1)
Base.step(x::YearStepRange)=Day(x.step)
Base.first(x::YearStepRange)=DateTime(x.startyear)+Day((x.startst-1)*x.step)
Base.last(x::YearStepRange)=DateTime(x.stopyear)+Day((x.stopst-1)*x.step)
function Base.getindex(x::YearStepRange,ind::Integer)
    y,d=divrem(ind-1+x.startst-1,x.NPY)
    DateTime(y+x.startyear)+Day(d)*x.step
end

abstract CubeAxis{T} <: AbstractCubeMem{T,1}
abstract CategoricalAxis{T} <: CubeAxis{T}
abstract RangeAxis{T} <: CubeAxis{T}
immutable TimeAxis <: RangeAxis{DateTime}
  values::YearStepRange
end

immutable MSCAxis <: RangeAxis{DateTime}
  values::YearStepRange
end
MSCAxis(n::Int)=MSCAxis(YearStepRange(1900,1,1900,n,ceil(Int,366/n),n))

immutable VariableAxis <: CategoricalAxis{UTF8String}
  values::Vector{UTF8String}
end

immutable LonAxis <: RangeAxis{Float64}
  values::FloatRange{Float64}
end
immutable LatAxis <: RangeAxis{Float64}
  values::FloatRange{Float64}
end
immutable SpatialPointAxis <: CubeAxis{Tuple{Float64,Float64}}
  values::Vector{Tuple{Float64,Float64}}
end
immutable CountryAxis<: CategoricalAxis{UTF8String}
  values::Vector{UTF8String}
end
immutable FitAxis <: CategoricalAxis{UTF8String}
    values::Vector{UTF8String}
end

immutable MethodAxis <: CategoricalAxis{ASCIIString}
    values::Vector{ASCIIString}
end

immutable QuantileAxis{T} <: CategoricalAxis{T}
    values::Vector{T}
end

immutable CountAxis{T} <: CategoricalAxis{T}
    values::Vector{T}
end

FitAxis()=FitAxis(["Intercept","Slope"])
Base.length(a::CubeAxis)=length(a.values)

immutable TimeScaleAxis <: CategoricalAxis{ASCIIString}
    values::Vector{ASCIIString}
end
TimeScaleAxis()=TimeScaleAxis(["Trend","LF-Variability","Seasonal Cycle","Fast Oscillations"])

axes(x::CubeAxis)=CubeAxis[x]
Base.ndims(::CubeAxis)=1

axname(a::CubeAxis)=split(split(string(typeof(a)),'.')[end],'{')[1]
axunits(::CubeAxis)="unknown"
axname(::LonAxis)="longitude"
axunits(::LonAxis)="degrees_east"
axname(::LatAxis)="latitude"
axunits(::LatAxis)="degrees_north"
axname(::TimeAxis)="time"
axname(::TimeScaleAxis)="time scale"
axname(::SpatialPointAxis)="location"

axVal2Index(axis::Union{LatAxis,LonAxis},v)=round(Int,axis.values.step)*round(Int,v*axis.values.divisor-axis.values.start-sign(axis.values.step))+2
axVal2Index(x,v)=v

getSubRange(x::CubeAxis,i)=x[i],nothing
getSubRange(x::TimeAxis,i)=sub(x,i),nothing

import Base.==
==(a::CubeAxis,b::CubeAxis)=a.values==b.values

function NcDim(a::RangeAxis{DateTime},start::Integer,count::Integer)
  if start + count - 1 > length(a.values)
    count = oftype(count,length(a.values) - start + 1)
  end
  tv=a.values[start:(start+count-1)]
  starttime=a.values[1]
  startyear=Dates.year(starttime)
  atts=Dict{Any,Any}("units"=>"days since $startyear-01-01")
  d=map(x->(x-starttime).value/86400000,tv)
  NcDim(axname(a),length(d),values=d,atts=atts)
end
#Default constructor
NcDim(a::CubeAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=collect(a.values[start:(start+count-1)]),atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::VariableAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=Float64[start:(start+count-1);],atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::CategoricalAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=Float64[start:(start+count-1);],atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::SpatialPointAxis,start::Integer,count::Integer)=NcDim("Spatial Point",count,values=collect(start:(start+count-1)))
NcDim(a::CubeAxis)=NcDim(a,1,length(a))

end
