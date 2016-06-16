module Axes
export CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis,Axes,YearStepRange,CategoricalAxis,RangeAxis
import NetCDF.NcDim
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
Base.length(a::CubeAxis)=length(a.values)

axes(x::CubeAxis)=CubeAxis[x]
Base.ndims(::CubeAxis)=1

axname(a::CubeAxis)=split(string(typeof(a)),'.')[end]
axunits(::CubeAxis)="unknown"
axname(::LonAxis)="longitude"
axunits(::LonAxis)="degrees_east"
axname(::LatAxis)="latitude"
axunits(::LatAxis)="degrees_north"
axname(::TimeAxis)="time"

getSubRange(x::CubeAxis,i)=x[i],nothing
getSubRange(x::TimeAxis,i)=sub(x,i),nothing

function NcDim(a::TimeAxis,start::Integer,count::Integer)
  if start + count - 1 > length(a.values)
    count = oftype(count,length(a.values) - start + 1)
  end
  tv=a.values[start:(start+count-1)]
  starttime=a.values[1]
  startyear=Dates.year(starttime)
  atts=Dict{Any,Any}("units"=>"days since $startyear")
  d=map(x->(x-starttime).value/86400000,tv)
  NcDim(axname(a),length(d),values=d,atts=atts)
end
#Default constructor
NcDim(a::CubeAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=collect(a.values[start:(start+count-1)]),atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::VariableAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=Float64[start:(start+count-1);],atts=Dict{Any,Any}("units"=>axunits(a)))


end
