export ConcatCube, concatenateCubes
export mapCubeSimple


type TransformedCube{T,N,F} <: AbstractCubeData{T,N}
  parents
  op::F
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end


function Base.map(op, incubes::AbstractCubeData...; T::DataType=eltype(incubes[1]))
  axlist=copy(axes(incubes[1]))
  N=ndims(incubes[1])
  for i=2:length(incubes)
    all(axes(incubes[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    ndims(incubes[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(incubes)...)
  TransformedCube{T,N,typeof(op)}(incubes,op,axlist,props)
end
Base.size(x::TransformedCube)=size(x.parents[1])
Base.size{T,N}(x::TransformedCube{T,N},i)=size(x.parents,i)
axes(v::TransformedCube)=v.cubeAxes
getCubeDes(v::TransformedCube)="Transformed cube $(getCubeDes(v.parents[1]))"
using Base.Cartesian
function _read{T,N}(x::TransformedCube{T,N},thedata::NTuple{2},r::CartesianRange{CartesianIndex{N}})
  aout,mout=thedata
  ainter=[]
  minter=[]
  for i=1:length(x.parents)
    c=x.parents[i]
    aouti=zeros(eltype(c),size(aout))
    mouti=zeros(UInt8,size(mout))
    _read(c,(aouti,mouti),r)
    push!(ainter,aouti)
    push!(minter,mouti)
  end
  map!(x.op,aout,ainter...)
  copy!(mout,minter[1])
  return aout,mout
end

ops2 = [:+, :-, :(./), :(.*),:/, :*, :max, :min]
for op in ops2
  eval(:(Base.$(op)(x::AbstractCubeData, y::AbstractCubeData)=map($op, x,y)))
  eval(:(Base.$(op)(x::AbstractCubeData, y::Number)          =map(i->i-y,x)))
  eval(:(Base.$(op)(x::Number, y::AbstractCubeData)          =map(i->x-i,y)))
end

ops1 = [:sin, :cos, :log, :log10, :exp, :abs]
for op in ops1
  eval(:(Base.$(op)(x::AbstractCubeData)=map($op, x)))
end




"""
    ConcatCube

Concatenate a list of cubes of the same type and axes to a composite cube.
"""
type ConcatCube{T,N} <: AbstractCubeData{T,N}
  cubelist::Vector
  catAxis::CubeAxis
  cubeAxes::Vector{CubeAxis}
  properties::Dict{String,Any}
end

"""
    function concatenateCubes(cubelist, catAxis::CategoricalAxis)

Concatenates a vector of datacubes that have identical axes to a new single cube along the new
axis `catAxis`
"""
function concatenateCubes(cl,catAxis::CubeAxis)
  length(catAxis.values)==length(cl) || error("catAxis must have same length as cube list")
  axlist=copy(axes(cl[1]))
  T=eltype(cl[1])
  N=ndims(cl[1])
  for i=2:length(cl)
    all(axes(cl[i]).==axlist) || error("All cubes must have the same axes, cube number $i does not match")
    eltype(cl[i])==T || error("All cubes must have the same element type, cube number $i does not match")
    ndims(cl[i])==N || error("All cubes must have the same dimension")
  end
  props=merge(cubeproperties.(cl)...)
  ConcatCube{T,N+1}(cl,catAxis,axlist,props)
end
Base.size(x::ConcatCube)=(size(x.cubelist[1])...,length(x.catAxis))
Base.size{T,N}(x::ConcatCube{T,N},i)=i==N ? length(x.catAxis) : size(x.cubelist[1],i)
axes(v::ConcatCube)=[v.cubeAxes;v.catAxis]
getCubeDes(v::ConcatCube)="Collection of $(getCubeDes(v.cubelist[1]))"
using Base.Cartesian
@generated function _read{T,N}(x::ConcatCube{T,N},thedata::NTuple{2},r::CartesianRange{CartesianIndex{N}})
  viewEx1=Expr(:call,:view,:aout,fill(Colon(),N-1)...,:j)
  viewEx2=Expr(:call,:view,:mout,fill(Colon(),N-1)...,:j)
  quote
    aout,mout=thedata
    rnew = CartesianRange(CartesianIndex(r.start.I[1:end-1]),CartesianIndex(r.stop.I[1:end-1]))
    for (j,i)=enumerate(r.start.I[end]:r.stop.I[end])
      a=$viewEx1
      m=$viewEx2
      _read(x.cubelist[i],(a,m),rnew)
    end
    return aout,mout
  end
end
