module Axes
export CubeAxis, QuantileAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis,
SpatialPointAxis,Axes,YearStepRange,CategoricalAxis,RangeAxis,axVal2Index,MSCAxis,
TimeScaleAxis, axname, @caxis_str
import NetCDF.NcDim
importall ..Cubes
using Base.Dates

immutable YearStepRange <: Range{Date}
    startyear::Int
    startst::Int
    stopyear::Int
    stopst::Int
    step::Int
    NPY::Int
end

function YearStepRange(start::Date,stop::Date,step::Day)
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
Base.next(x::YearStepRange,st)=(Date(st[1])+Day((st[2]-1)*x.step),st[2]==x.NPY ? (st[1]+1,1) : (st[1],st[2]+1))
Base.done(x::YearStepRange,st)=(st[1]==x.stopyear && st[2]==x.stopst+1) || (st[1]==x.stopyear+1 && st[2]==1)
Base.step(x::YearStepRange)=Day(x.step)
Base.first(x::YearStepRange)=Date(x.startyear)+Day((x.startst-1)*x.step)
Base.last(x::YearStepRange)=Date(x.stopyear)+Day((x.stopst-1)*x.step)
function Base.getindex(x::YearStepRange,ind::Integer)
    y,d=divrem(ind-1+x.startst-1,x.NPY)
    Date(y+x.startyear)+Day(d)*x.step
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
* `TimeScaleAxis` time scales after time series decomposition
* `QuantileAxis` represents different quantiles

### Cotinuous Axes

* `LonAxis` longitudes
* `LatAxis` latitudes
* `TimeAxis` time
* `MSCAxis` time step inside a year (for seasonal statistics)

"""
abstract CubeAxis{T,S} <: AbstractCubeMem{T,1}

"""
    CategoricalAxis{T,S}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol).
The default constructor is:

    CategoricalAxis(axname::String,values::Vector{T})

"""
immutable CategoricalAxis{T,S} <: CubeAxis{T,S}
  values::Vector{T}
end


CategoricalAxis{T}(s::Symbol,v::Vector{T})=CategoricalAxis{T,s}(v)
CategoricalAxis(s::AbstractString,v::Vector)=CategoricalAxis(Symbol(s),v)

@defineCatAxis Variable String
@defineCatAxis SpatialPoint Tuple{Float64,Float64}
@defineCatAxis TimeScale String
@defineCatAxis Quantile Float64

"""
    RangeAxis{T,S,R}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol) and `R` the type of the
range which is used to represent the axis values.
The default constructor is:

    RangeAxis(axname::String,values::Range{T})

"""
immutable RangeAxis{T,S,R} <: CubeAxis{T,S}
  values::R
end
RangeAxis{T}(s::Symbol,v::Range{T})=RangeAxis{T,s,typeof(v)}(v)
RangeAxis(s::AbstractString,v)=RangeAxis(Symbol(s),v)

@defineRanAxis Time Date YearStepRange
@defineRanAxis MSC Date YearStepRange
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
axVal2Index{T,S,F<:FloatRange}(axis::RangeAxis{T,S,F},v;fuzzy::Bool=false)=min(max(round(Int,(v-first(axis.values))/step(axis.values))+1,1),length(axis))
function axVal2Index(axis::CategoricalAxis{String},v::String;fuzzy::Bool=false)
  r=findfirst(axis.values,v)
  if r==0
    if fuzzy
      r=find(i->startswith(lowercase(i),lowercase(v)),axis.values)
      if length(r)==1
        return(r[1])
      else
        error("Could not find unique value of $v in $axis")
      end
    else
      error("$v not found in $axis")
    end
  end
  r
end
axVal2Index(x,v;fuzzy::Bool=false)=min(max(v,1),length(x))

getSubRange(x::CubeAxis,i)=x[i],nothing
getSubRange(x::TimeAxis,i)=sub(x,i),nothing

macro caxis_str(s)
  :(CategoricalAxis{String,$(QuoteNode(Symbol(s)))})
end

import Base.==
==(a::CubeAxis,b::CubeAxis)=a.values==b.values

function NcDim(a::CubeAxis{Date},start::Integer,count::Integer)
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
