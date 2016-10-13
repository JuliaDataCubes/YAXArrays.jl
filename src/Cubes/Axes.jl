module Axes
export CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis,
SpatialPointAxis,Axes,YearStepRange,CategoricalAxis,RangeAxis,axVal2Index,MSCAxis,
TimeScaleAxis
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

macro defineCatAxis(axname,eltype)
  newname=esc(Symbol(string(axname,"Axis")))
  quote
    typealias $newname CategoricalAxis{$eltype,$(QuoteNode(axname))}
  end
end

macro defineRanAxis(axname,eltype,rantype)
  newname=esc(Symbol(string(axname,"Axis")))
  quote
    typealias $newname RangeAxis{$eltype,$(QuoteNode(axname)),$rantype}
  end
end

"""
    abstract CubeAxis{T} <: AbstractCubeData{T,1}

Supertype of all axes. Every `CubeAxis` is 1D Cube itself and can be passed
to mapCube operationes. Although all cube axes are instances of the parametric typealias
[CategoricalAxis](@ref) and [RangeAxis](@ref), there are some typealiases defined
to provide shorter and more convenient names for commonly used cube axes. Here is a list
of the aliases:

### Categorical Axes

* `VariableAxis` represents different variables
* `SpatialPointAxis` represents a list of coordinates
* `CountryAxis` countries
* `TimeScaleAxis` time scasles after time series decomposition

### Cotinuous Axes

* `LonAxis` longitudes
* `LatAxis` latitudes
* `TimeAxis` time
* `MSCAxis` time step inside a year (for seasonal statistics)

"""
abstract CubeAxis{T} <: AbstractCubeMem{T,1}

"""
    CategoricalAxis{T,S}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol).
The default constructor is:

    CategoricalAxis(axname::String,values::Vector{T})

"""
immutable CategoricalAxis{T,S} <: CubeAxis{T}
  values::Vector{T}
end


CategoricalAxis{T}(s::Symbol,v::Vector{T})=CategoricalAxis{T,s}(v)
CategoricalAxis(s::AbstractString,v::Vector)=CategoricalAxis(Symbol(s),v)

@defineCatAxis Variable String
@defineCatAxis SpatialPoint String
@defineCatAxis Country String
@defineCatAxis TimeScale String

"""
    RangeAxis{T,S,R}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol) and `R` the type of the
range which is used to represent the axis values.
The default constructor is:

    RangeAxis(axname::String,values::Range{T})

"""
immutable RangeAxis{T,S,R} <: CubeAxis{T}
  values::R
end
RangeAxis{T}(s::Symbol,v::Range{T})=RangeAxis{T,s,typeof(v)}(v)
RangeAxis(s::AbstractString,v)=RangeAxis(Symbol(s),v)

@defineRanAxis Time DateTime YearStepRange
@defineRanAxis MSC DateTime YearStepRange
@defineRanAxis Lon Float64 FloatRange{Float64}
@defineRanAxis Lat Float64 FloatRange{Float64}

Base.length(a::CubeAxis)=length(a.values)

MSCAxis(n::Int)=MSCAxis(YearStepRange(1900,1,1900,n,ceil(Int,366/n),n))

axes(x::CubeAxis)=CubeAxis[x]
Base.ndims(::CubeAxis)=1

axname{T,S}(::CategoricalAxis{T,S})=string(S)
axname{T,S}(::RangeAxis{T,S})=string(S)
axunits(::CubeAxis)="unknown"
axunits(::LonAxis)="degrees_east"
axunits(::LatAxis)="degrees_north"
axVal2Index{T,S,F<:FloatRange}(axis::RangeAxis{T,S,F},v)=min(max(round(Int,axis.values.step)*round(Int,v*axis.values.divisor-axis.values.start-sign(axis.values.step))+2,1),length(axis))
axVal2Index(x,v)=min(max(v,1),length(x))

getSubRange(x::CubeAxis,i)=x[i],nothing
getSubRange(x::TimeAxis,i)=sub(x,i),nothing

import Base.==
==(a::CubeAxis,b::CubeAxis)=a.values==b.values

function NcDim(a::CubeAxis{DateTime},start::Integer,count::Integer)
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
NcDim{T<:Real}(a::CubeAxis{T},start::Integer,count::Integer)=NcDim(axname(a),count,values=collect(a.values[start:(start+count-1)]),atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::CubeAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=Float64[start:(start+count-1);],atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::CubeAxis)=NcDim(a,1,length(a))

end
