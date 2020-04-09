module Axes
import NetCDF.NcDim
import ..Cubes: caxes, _read, Cubes, AbstractCubeData
using Dates
using Base.Iterators: take, drop

macro defineCatAxis(axname,eltype)
  newname=esc(Symbol(string(axname,"Axis")))
  quote
    const $newname = CategoricalAxis{T,$(QuoteNode(axname)),R} where R<:AbstractVector{T} where T<:$(eltype)
    $(newname)(v::AbstractVector{T}) where T = CategoricalAxis{T,$(QuoteNode(axname)),typeof(v)}(v)
  end
end

macro defineRanAxis(axname,eltype)
  newname=esc(Symbol(string(axname,"Axis")))
  quote
    const $newname = RangeAxis{T,$(QuoteNode(axname)),R} where R<:AbstractVector{T} where T<:$(eltype)
    $(newname)(v::AbstractVector{T}) where T = RangeAxis{T,$(QuoteNode(axname)),typeof(v)}(v)
  end
end

"""
    abstract CubeAxis{T} <: AbstractCubeData{T,1}

Supertype of all axes. Every `CubeAxis` is an 1D Cube itself and can be passed
to mapCube operations. Although all cube axes are instances of the parametric typealias
`CategoricalAxis` and `RangeAxis`, there are some typealiases defined
to provide shorter and more convenient names for commonly used cube axes. Here is a list
of the aliases:

### Categorical Axes

* `VariableAxis` represents different variables
* `SpatialPointAxis` represents a list of coordinates
* `CountryAxis` countries
* `ScaleAxis` time scales after time series decomposition
* `QuantileAxis` represents different quantiles

### Continuous Axes

* `LonAxis` longitudes
* `LatAxis` latitudes
* `TimeAxis` time
* `MSCAxis` time step inside a year (for seasonal statistics)

"""
abstract type CubeAxis{T,S} <: AbstractCubeData{T,1} end

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
struct CategoricalAxis{T,S,RT} <: CubeAxis{T,S}
  values::RT
end

CategoricalAxis(s::Symbol,v)=CategoricalAxis{eltype(v),s,typeof(v)}(v)
CategoricalAxis(s::AbstractString,v)=CategoricalAxis(Symbol(s),v)

@defineCatAxis Variable String
@defineCatAxis SpatialPoint Tuple{Number,Number}
@defineCatAxis Scale String
@defineCatAxis Quantile AbstractFloat

struct RangeAxis{T,S,R<:AbstractVector{T}} <: CubeAxis{T,S}
  values::R
end

"""
    RangeAxis{T,S,R}

To represent axes that are categorical, where `T` is the element type.
The type parameter `S` denotes the axis name (a symbol) and `R` the type of the
range which is used to represent the axis values.
The default constructor is:

    RangeAxis(axname::String,values::Range{T})

"""
RangeAxis(s::Symbol,v::AbstractVector{T}) where T = RangeAxis{T,s,typeof(v)}(v)
RangeAxis(s::AbstractString,v)=RangeAxis(Symbol(s),v)

@defineRanAxis MSC TimeType
@defineRanAxis Lon Number
@defineRanAxis Lat Number
@defineRanAxis Time TimeType

Base.length(a::CubeAxis)=length(a.values)

MSCAxis(n::Int)=MSCAxis(DateTime(1900):Day(ceil(Int,366/n)):DateTime(1900,12,31,23,59,59))

"""
    axcopy(x,vals)

Makes a copy of a `CubeAxis` with the values `vals`
"""
axcopy(ax::RangeAxis,vals) = RangeAxis(axname(ax),vals)
axcopy(ax::CategoricalAxis,vals) = CategoricalAxis(axname(ax),vals)


Base.show(io::IO,a::RangeAxis)=print(io,rpad(Axes.axname(a),20," "),"Axis with ",length(a)," Elements from ",first(a.values)," to ",last(a.values))
function Base.show(io::IO,a::CategoricalAxis)
  print(io,rpad(Axes.axname(a),20," "), "Axis with ", length(a), " elements: ")
  if length(a.values)<10
    for v in a.values
      print(io,v," ")
    end
  else
    for v in take(a.values,2)
      print(io,v," ")
    end
    print(io,".. ")
    for v in drop(a.values,length(a.values)-2)
      print(io,v," ")
    end
  end
end

caxes(x::CubeAxis)=CubeAxis[x]

axname(::Type{<:CubeAxis{<:Any,U}}) where U = string(U)
axname(::CubeAxis{<:Any,U}) where U = string(U)
axsym(::CubeAxis{<:Any,S}) where S = S
axunits(::CubeAxis)="unknown"
axunits(::LonAxis)="degrees_east"
axunits(::LatAxis)="degrees_north"

get_step(r::AbstractRange)=step(r)
get_step(r::AbstractVector)=length(r)==0 ? zero(eltype(r)) : r[2]-r[1]

axVal2Index_ub(a::RangeAxis, v; fuzzy=false)=axVal2Index(a,v-abshalf(get_step(a.values)),fuzzy=fuzzy)
axVal2Index_lb(a::RangeAxis, v; fuzzy=false)=axVal2Index(a,v+abshalf(get_step(a.values)),fuzzy=fuzzy)

axVal2Index_ub(a::RangeAxis, v::Date; fuzzy=false)=axVal2Index(a,DateTime(v)-abshalf(get_step(a.values)),fuzzy=fuzzy)
axVal2Index_lb(a::RangeAxis, v::Date; fuzzy=false)=axVal2Index(a,DateTime(v)+abshalf(get_step(a.values)),fuzzy=fuzzy)

abshalf(a) = abs(a/2)
abshalf(a::Day) = abs(Millisecond(a)/2)
abshalf(a::Month) = iseven(Dates.value(a)) ? a/2 : Month(a÷2) + Day(15)

get_bb(ax::RangeAxis) = first(ax.values)-abshalf(get_step(ax.values)), last(ax.values)+abshalf(get_step(ax.values))
function axisfrombb(name,bb,n)
  offs = (bb[2]-bb[1])/(2*n)
  RangeAxis(name,range(bb[1]+offs,bb[2]-offs,length=n))
end

function axVal2Index(a::RangeAxis{<:Any,<:Any,<:AbstractRange},v;fuzzy=false)
  dt = v-first(a.values)
  r = round(Int,dt/step(a.values))+1
  return max(1,min(length(a.values),r))
end

convert_time(T::Type{<:TimeType}, v::TimeType) = T(year(v), month(v), day(v), hour(v), minute(v), second(v))
convert_time(T::Type{<:TimeType}, v::Date) = T(year(v), month(v), day(v), 0, 0, 0)
convert_time(::Type{Date},v::TimeType) = Date(year(v),month(v),day(v))
convert_time(::Type{Date},v::Date) = Date(year(v),month(v),day(v))

function axVal2Index(a::RangeAxis{T},v;fuzzy=false) where T<:TimeType
  vconverted = convert_time(T,v)
  dd = map(i->abs((i-vconverted)),a.values)
  mi,ind = findmin(dd)
  return ind
end
function axVal2Index(a::RangeAxis{T,<:Any,<:AbstractRange},v;fuzzy=false) where T<:TimeType
  vconverted = convert_time(T,v)
  dd = map(i->abs((i-vconverted)),a.values)
  mi,ind = findmin(dd)
  return ind
end
function axVal2Index(axis::CategoricalAxis{String},v::String;fuzzy::Bool=false)
  r=findfirst(isequal(v),axis.values)
  if r==nothing
    if fuzzy
      r=findall(axis.values) do i
        startswith(lowercase(i),lowercase(v[1:min(length(i),length(v))]))
      end
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
axVal2Index(x,v::CartesianIndex{1};fuzzy::Bool=false)=min(max(v.I[1],1),length(x))
function axVal2Index(x,v;fuzzy::Bool=false)
  i = findfirst(isequal(v),x.values)
  isa(i,Nothing) && error("Value $v not found in x")
  return i
end
abstract type AxisDescriptor end
struct ByName <: AxisDescriptor
  name::String
end
struct ByInference <: AxisDescriptor end
struct ByType{T} <: AxisDescriptor
  t::Type{T}
end
struct ByValue <: AxisDescriptor
  v::CubeAxis
end
struct ByFunction <: AxisDescriptor
  f::Function
end

findAxis(a::Any,c::Any)=findAxis(a,caxes(c))
get_descriptor(a::String)=ByName(a)
get_descriptor(a::Type{T}) where {T<:CubeAxis}=ByType(a)
get_descriptor(a::CubeAxis)=ByValue(a)
get_descriptor(a::Function)=ByFunction(a)
get_descriptor(a)=error("$a is not a valid axis description")
get_descriptor(a::AxisDescriptor)=a

const VecOrTuple{S} = Union{Vector{<:S},NTuple{<:Any,S}} where S


"Find a certain axis type in a vector of Cube axes and returns the index"
function findAxis(bt::ByType,v::VecOrTuple{S}) where S<:CubeAxis
  a=bt.t
  for i=1:length(v)
    isa(v[i],a) && return i
  end
  return nothing
end
function findAxis(bs::ByName,axlist::VecOrTuple{T}) where T<:CubeAxis
  matchstr=bs.name
  ism=findall(i->startswith(lowercase(axname(i)),lowercase(matchstr)),axlist)
  isempty(ism) && return nothing
  if length(ism)>1
    f = axlist[ism[1]]
    all(i->i==f,ism) || error("Multiple axes found matching string $matchstr")
    return f
  else
    return ism[1]
  end
end
function findAxis(bv::ByValue,axlist::VecOrTuple{T}) where T<:CubeAxis
  v=bv.v
  return findfirst(i->i==v,axlist)
end
function getAxis(desc,axlist::VecOrTuple{T}) where T<:CubeAxis
  i = findAxis(desc,axlist)
  if isa(i,Nothing)
    return nothing
  else
    return axlist[i]
  end
end
getOutAxis(desc,axlist,incubes,pargs,f) = getAxis(desc,unique(axlist))
function getOutAxis(desc::ByFunction,axlist,incubes,pargs,f)
  outax = desc.f(incubes,pargs)
  isa(outax,CubeAxis) || error("Axis Generation function $(desc.f) did not return an axis")
  outax
end
import DataStructures: counter
function getOutAxis(desc::Tuple{ByInference},axlist,incubes,pargs,f)
  inAxes = map(caxes,incubes)
  inAxSmall = map(i->filter(j->in(j,axlist),i) |>collect,inAxes)
  inSizes = map(i->(map(length,i)...,),inAxSmall)
  intypes = map(eltype, incubes)
  testars = map((s,it)->zeros(it,s...),inSizes, intypes)
  map(testars) do ta
    ta .= rand(Base.nonmissingtype(eltype(ta)),size(ta)...)
    if eltype(ta) >: Missing
      # Add some missings
      randind = rand(1:length(ta),length(ta)÷10)
      ta[randind] .= missing
    end
  end
  resu = f(testars...,pargs...)
  isa(resu,AbstractArray) || isa(resu,Number) || isa(resu,Missing) || error("Function must return an array or a number")
  (isa(resu,Number) || isa(resu,Missing)) && return ()
  outsizes = size(resu)
  outaxes = map(outsizes,1:length(outsizes)) do s,il
    if s>2
      i = findall(i->i==s,length.(axlist))
      if length(i)==1
        return axlist[i[1]]
      elseif length(i)>1
        @info "Found multiple matching axes for output dimension $il"
      end
    end
    return RangeAxis("OutAxis$(il)",1:s)
  end
  if !allunique(outaxes)
    #TODO: fallback with axis renaming in this case
    error("Could not determine unique output axes from output shape")
  end
  return (outaxes...,)
end
"""
    getAxis(desc::String, c::AbstractCubeData)

Given the string of an axis name and a cube, returns this axis of the cube.
"""
getAxis(desc,c)=getAxis(desc,caxes(c))
getAxis(desc::ByValue,axlist::Vector{T}) where {T<:CubeAxis}=desc.v

"Fallback method"
findAxis(a,axlist::VecOrTuple{T}) where T<:CubeAxis = findAxis(get_descriptor(a),axlist)

getSubRange(x::CubeAxis,i)=x.values[i],nothing
getSubRange(x::TimeAxis,i)=view(x,i),nothing

renameaxis(r::RangeAxis{T,<:Any,V}, newname) where {T,V} = RangeAxis{T,Symbol(newname),V}(r.values)
renameaxis(r::CategoricalAxis{T,<:Any,V}, newname) where {T,V} = CategoricalAxis{T,Symbol(newname),V}(r.values)

function _read(ax::CubeAxis, ar::AbstractArray, I::CartesianIndices)
  ar[:] .= ax.values[I.indices[1]]
end

macro caxis_str(s)
  :(CategoricalAxis{String,$(QuoteNode(Symbol(s)))})
end

import Base.==
import Base.isequal
==(a::CubeAxis,b::CubeAxis)=(a.values==b.values) && (axname(a)==axname(b))
isequal(a::CubeAxis, b::CubeAxis) = a==b

import CFTime: timeencode
function NcDim(a::CubeAxis{T},start::Integer,count::Integer) where T<:TimeType
  if start + count - 1 > length(a.values)
    count = oftype(count,length(a.values) - start + 1)
  end
  tv=a.values[start:(start+count-1)]
  startyear=Dates.year(first(a.values))
  starttime=T(startyear)
  timeunits = "days since $startyear-01-01"
  atts=Dict{Any,Any}("units"=>timeunits, "calendar"=>"standard")
  d = timeencode(tv, timeunits)
  NcDim(axname(a),length(d),values=d,atts=atts)
end

#Default constructor
NcDim(a::CubeAxis{T},start::Integer,count::Integer) where {T<:Real}=NcDim(axname(a),count,values=collect(a.values[start:(start+count-1)]),atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::CubeAxis,start::Integer,count::Integer)=NcDim(axname(a),count,values=Float64[start:(start+count-1);],atts=Dict{Any,Any}("units"=>axunits(a)))
NcDim(a::CubeAxis)=NcDim(a,1,length(a))

end
