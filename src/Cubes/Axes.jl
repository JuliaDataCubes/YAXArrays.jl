module Axes
export CubeAxis, QuantileAxis, TimeAxis, TimeHAxis, VariableAxis, LonAxis, LatAxis, CountryAxis,
SpatialPointAxis,Axes,YearStepRange,CategoricalAxis,RangeAxis,axVal2Index,MSCAxis,
TimeScaleAxis, axname, @caxis_str, findAxis, AxisDescriptor, get_descriptor, ByName, ByType, ByValue, ByFunction, getAxis,
getOutAxis
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
    startst=ceil(Int,startday/Dates.value(step))
    stopyear=year(stop)
    stopday=dayofyear(stop)
    stopst=ceil(Int,stopday/Dates.value(step))
    NPY=ceil(Int,366/Dates.value(step))
    YearStepRange(startyear,startst,stopyear,stopst,Dates.value(step),NPY)
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
    const $newname = _CategoricalAxis{T,$(QuoteNode(axname)),R} where R<:AbstractVector{T} where T<:$(eltype)
    $(newname)(v::AbstractVector{T}) where T = CategoricalAxis{T,$(QuoteNode(axname)),typeof(v)}(v)
  end
end

macro defineRanAxis(axname,eltype)
  newname=esc(Symbol(string(axname,"Axis")))
  quote
    const $newname = _RangeAxis{T,$(QuoteNode(axname)),R} where R<:AbstractVector{T} where T<:$(eltype)
    $(newname)(v::AbstractVector{T}) where T = RangeAxis{T,$(QuoteNode(axname)),typeof(v)}(v)
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
abstract type CubeAxis{T,S} <: AbstractCubeMem{T,1} end

Base.size(x::CubeAxis)=(length(x.values),)
Base.size(x::CubeAxis,i)=i==1 ? length(x.values) : error("Axis has only a single dimension")
Base.ndims(x::CubeAxis)=1


"""
    CategoricalAxis{T,S}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol).
The default constructor is:

    CategoricalAxis(axname::String,values::Vector{T})

"""
immutable _CategoricalAxis{T,S,RT} <: CubeAxis{T,S}
  values::RT
end
const CategoricalAxis = _CategoricalAxis{T,S,RT} where RT<:AbstractVector{T} where S where T


CategoricalAxis{T}(s::Symbol,v::AbstractVector{T})=CategoricalAxis{T,s,typeof(v)}(v)
CategoricalAxis(s::AbstractString,v::AbstractVector)=CategoricalAxis(Symbol(s),v)

@defineCatAxis Variable String
@defineCatAxis SpatialPoint Tuple{Number,Number}
@defineCatAxis TimeScale String
@defineCatAxis Quantile AbstractFloat

"""
    RangeAxis{T,S,R}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol) and `R` the type of the
range which is used to represent the axis values.
The default constructor is:

    RangeAxis(axname::String,values::Range{T})

"""
immutable _RangeAxis{T,S,R} <: CubeAxis{T,S}
  values::R
end
const RangeAxis = _RangeAxis{T,S,R} where R<:AbstractVector{T} where S where T

RangeAxis(s::Symbol,v::AbstractVector{T}) where T = RangeAxis{T,s,typeof(v)}(v)
RangeAxis(s::AbstractString,v)=RangeAxis(Symbol(s),v)



@defineRanAxis MSC TimeType
@defineRanAxis Lon Number
@defineRanAxis Lat Number
@defineRanAxis Time TimeType

Base.length(a::CubeAxis)=length(a.values)

MSCAxis(n::Int)=MSCAxis(YearStepRange(1900,1,1900,n,ceil(Int,366/n),n))

axes(x::CubeAxis)=CubeAxis[x]

axname{T,S}(::CategoricalAxis{T,S})=string(S)
axname{T,S}(::RangeAxis{T,S})=string(S)
axunits(::CubeAxis)="unknown"
axunits(::LonAxis)="degrees_east"
axunits(::LatAxis)="degrees_north"
function axVal2Index{T,S,F<:StepRange}(a::RangeAxis{T,S,F},v;fuzzy=false)
  dt = v-first(a.values)
  r = round(Int,dt/step(a.values))+1
  return max(1,min(length(a.values),r))
end
function axVal2Index{T<:DateTime,S,F<:Range}(a::RangeAxis{T,S,F},v;fuzzy=false)
  dt = v-first(a.values)
  r = round(Int,dt/Millisecond(step(a.values)))+1
  return max(1,min(length(a.values),r))
end
function axVal2Index{T<:Date,S,F<:YearStepRange}(a::RangeAxis{T,S,F},v::Date;fuzzy=false)
  y = year(v)
  d = dayofyear(v)
  r = (y-a.values.startyear)*a.values.NPY + d÷a.values.step + 1
  return max(1,min(length(a.values),r))
end
function axVal2Index{T<:Date,S,F<:StepRange}(a::_RangeAxis{T,S,F},v::Date;fuzzy=false)
  dd = map(i->abs((i-v).value),a.values)
  mi,ind = findmin(dd)
  return ind
end
axVal2Index{T,S,F<:StepRangeLen}(axis::_RangeAxis{T,S,F},v;fuzzy::Bool=false)=min(max(round(Int,(v-first(axis.values))/step(axis.values))+1,1),length(axis))
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

abstract type AxisDescriptor end
getAxis(d::Any,v::Any)=error("getAxis not defined for $d $v")
immutable ByName <: AxisDescriptor
  name::String
end

immutable ByType{T} <: AxisDescriptor
  t::Type{T}
end
immutable ByValue <: AxisDescriptor
  v::CubeAxis
end
immutable ByFunction <: AxisDescriptor
  f::Function
end

findAxis(a,c::AbstractCubeData)=findAxis(a,axes(c))
get_descriptor(a::String)=ByName(a)
get_descriptor{T<:CubeAxis}(a::Type{T})=ByType(a)
get_descriptor(a::CubeAxis)=ByValue(a)
get_descriptor(a::Function)=ByFunction(a)
get_descriptor(a)=error("$a is not a valid axis description")
get_descriptor(a::AxisDescriptor)=a


"Find a certain axis type in a vector of Cube axes and returns the index"
function findAxis{S<:CubeAxis}(bt::ByType,v::Vector{S})
  a=bt.t
  for i=1:length(v)
    isa(v[i],a) && return i
  end
  return 0
end
function findAxis{T<:CubeAxis}(bs::ByName,axlist::Vector{T})
  matchstr=bs.name
  ism=map(i->startswith(lowercase(axname(i)),lowercase(matchstr)),axlist)
  sism=sum(ism)
  sism==0 && error("No axis found matching string $matchstr")
  sism>1 && error("Multiple axes found matching string $matchstr")
  i=findfirst(ism)
end
function findAxis{T<:CubeAxis}(bv::ByValue,axlist::Vector{T})
  v=bv.v
  return findfirst(i->i==v,axlist)
end
function getAxis{T<:CubeAxis}(desc,axlist::Vector{T})
  i = findAxis(desc,axlist)
  if i==0
    error("Axis $desc not found in $axlist")
  else
    return axlist[i]
  end
end
getOutAxis(desc,axlist,incubes,pargs,f) = getAxis(desc,axlist)
function getOutAxis(desc::ByFunction,axlist,incubes,pargs,f)
  outax = desc.f(incubes,pargs)
  isa(outax,CubeAxis) || error("Axis Generation function $(desc.f) did not return an axis")
  outax
end

getAxis(desc,c::AbstractCubeData)=getAxis(desc,axes(c))
getAxis{T<:CubeAxis}(desc::ByValue,axlist::Vector{T})=desc.v

"Fallback method"
findAxis(a,axlist)=findAxis(get_descriptor(a),axlist)

getSubRange(x::CubeAxis,i)=x.values[i],nothing
getSubRange(x::TimeAxis,i)=view(x,i),nothing

macro caxis_str(s)
  :(CategoricalAxis{String,$(QuoteNode(Symbol(s)))})
end

import Base.==
==(a::CubeAxis,b::CubeAxis)=(a.values==b.values) && (axname(a)==axname(b))

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
