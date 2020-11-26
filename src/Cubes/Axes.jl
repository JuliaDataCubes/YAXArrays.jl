module Axes
import ..Cubes: caxes, Cubes
using Dates
using Base.Iterators: take, drop

"""
    abstract CubeAxis{T}

Supertype of all axes. Every `CubeAxis` is an 1D Cube itself and can be passed
to mapCube operations.
"""
abstract type CubeAxis{T,S} end

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

Base.length(a::CubeAxis)=length(a.values)

"""
    axcopy(x,vals)

Makes a copy of a `CubeAxis` with the values `vals`
"""
axcopy(ax::RangeAxis,vals) = RangeAxis(axname(ax),vals)
axcopy(ax::CategoricalAxis,vals) = CategoricalAxis(axname(ax),vals)
axcopy(ax::RangeAxis) = RangeAxis(axname(ax),copy(ax.values))
axcopy(ax::CategoricalAxis) = CategoricalAxis(axname(ax),copy(ax.values))


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
  if r===nothing
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
  if isa(i,Nothing)
      if fuzzy==true
          dd = map(i->abs(i-v),x.values)
          mi,ind = findmin(dd)
          return ind
      else
          error("Value $v not found in x")
      end
  else
      return i
  end
end
abstract type AxisDescriptor end
struct ByName <: AxisDescriptor
  name::String
end
struct ByInference <: AxisDescriptor end
struct ByValue <: AxisDescriptor
  v::CubeAxis
end
struct ByFunction <: AxisDescriptor
  f::Function
end

const VecOrTuple{S} = Union{Vector{<:S},Tuple{Vararg{<:S}}} where S

#findAxis(a::Any,c::VecOrTuple{<:CubeAxis}) = findAxis(get_descriptor(desc),c)
get_descriptor(a::String)=ByName(a)
get_descriptor(a::Symbol)=ByName(String(a))
get_descriptor(a::CubeAxis)=ByValue(a)
get_descriptor(a::Function)=ByFunction(a)
get_descriptor(a)=error("$a is not a valid axis description")
get_descriptor(a::AxisDescriptor)=a



function findAxis(bs::ByName,axlist::VecOrTuple{CubeAxis})
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
function findAxis(bv::ByValue,axlist::VecOrTuple{CubeAxis})
  v=bv.v
  return findfirst(i->i==v,axlist)
end
function getAxis(desc,axlist::VecOrTuple{CubeAxis})
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
    getAxis(desc::String, c)

Given the string of an axis name and a cube, returns this axis of the cube.
"""
getAxis(desc,c)=getAxis(desc,caxes(c))
getAxis(desc::ByValue,axlist::Vector{T}) where {T<:CubeAxis}=desc.v

"Fallback method"
findAxis(desc,c)=findAxis(desc,caxes(c))
findAxis(a,axlist::VecOrTuple{CubeAxis}) = findAxis(get_descriptor(a),axlist)

renameaxis(r::RangeAxis{T,<:Any,V}, newname) where {T,V} = RangeAxis{T,Symbol(newname),V}(r.values)
renameaxis(r::CategoricalAxis{T,<:Any,V}, newname) where {T,V} = CategoricalAxis{T,Symbol(newname),V}(r.values)

import Base.==
import Base.isequal
==(a::CubeAxis,b::CubeAxis)=(a.values==b.values) && (axname(a)==axname(b))
isequal(a::CubeAxis, b::CubeAxis) = a==b

using YAXArrayBase: YAXArrayBase
#Implement yaxarray interface
YAXArrayBase.dimname(x::CubeAxis,_) = axname(x)
YAXArrayBase.dimvals(x::CubeAxis,_) = x.values
YAXArrayBase.iscontdim(::RangeAxis,_) = true
YAXArrayBase.iscontdim(::CategoricalAxis,_) = false
end
