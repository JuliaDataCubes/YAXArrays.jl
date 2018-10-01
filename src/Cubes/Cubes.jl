"""
The functions provided by ESDL are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
export Axes, AbstractCubeData, getSubRange, readCubeData, AbstractCubeMem, axesCubeMem,CubeAxis, TimeAxis, TimeHAxis, QuantileAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis, caxes,
       AbstractSubCube, CubeMem, EmptyCube, YearStepRange, _read, saveCube, loadCube, RangeAxis, CategoricalAxis, axVal2Index, MSCAxis,
       getSingVal, ScaleAxis, axname, @caxis_str, rmCube, cubeproperties, findAxis, AxisDescriptor, get_descriptor, ByName, ByType, ByValue, ByFunction, getAxis,
       getOutAxis, ByInference

include("Mask.jl")
import .Mask: MaskArray

"""
    AbstractCubeData{T,N}

Supertype of all cubes. `T` is the data type of the cube and `N` the number of
dimensions. Beware that an `AbstractCubeData` does not implement the `AbstractArray`
interface. However, the `ESDL` functions [`mapCube`](@ref), [`reduceCube`](@ref),
[`readCubeData`](@ref), [`plotMAP`](@ref) and [`plotXY`](@ref) will work on any subtype
of `AbstractCubeData`
"""
abstract type AbstractCubeData{T,N} end

"""
getSingVal reads a single point from the cube's data
"""
getSingVal(c::AbstractCubeData,a...)=error("getSingVal called in the wrong way with argument types $(typeof(c)), $(map(typeof,a))")


"""
    readCubeData(cube::AbstractCubeData)
"""
function readCubeData(x::AbstractCubeData{T,N}) where {T,N}
  s=size(x)
  aout,mout=zeros(T,s...),zeros(UInt8,s...)
  r=CartesianIndices(s)
  _read(x,(aout,mout),r)
  CubeMem(collect(CubeAxis,caxes(x)),aout,mout)
end

"""
This function calculates a subset of a cube's data
"""
function subsetCubeData end

#"""
#Internal function to read a range from a datacube
#"""
#_read(c::AbstractCubeData,d,r::CartesianRange)=error("_read not implemented for $(typeof(c))")

"Returns the axes of a Cube"
caxes(c::AbstractCubeData)=error("Axes function not implemented for $(typeof(c))")

"Number of dimensions"
Base.ndims(::AbstractCubeData{T,N}) where {T,N}=N

cubeproperties(::AbstractCubeData)=Dict{String,Any}()

"Chunks, if given"
cubechunks(c::AbstractCubeData) = (size(c,1),map(i->1,2:ndims(c)))

"Offset of the first chunk"
chunkoffset(c::AbstractCubeData) = ntuple(i->0,ndims(c))

function iscompressed end

"Supertype of all subtypes of the original data cube"
abstract type AbstractSubCube{T,N} <: AbstractCubeData{T,N} end


"Supertype of all in-memory representations of a data cube"
abstract type AbstractCubeMem{T,N} <: AbstractCubeData{T,N} end

include("Axes.jl")
using .Axes
import .Axes: getOutAxis, getAxis
struct EmptyCube{T}<:AbstractCubeData{T,0} end
caxes(c::EmptyCube)=CubeAxis[]

"""
    CubeMem{T,N} <: AbstractCubeMem{T,N}

An in-memory data cube. It is returned by applying [mapCube](@ref) when
the output cube is small enough to fit in memory or by explicitly calling
`readCubeData` on any type of cube.

### Fields

* `axes` a `Vector{CubeAxis}` containing the Axes of the Cube
* `data` N-D array containing the data
* `mask` N-D array containgin the mask

"""
mutable struct CubeMem{T,N} <: AbstractCubeMem{T,N}
  axes::Vector{CubeAxis}
  data::Array{T,N}
  mask::Array{UInt8,N}
  properties::Dict{String}
end

CubeMem(axes::Vector{CubeAxis},data,mask) = CubeMem(axes,data,mask,Dict{String,Any}())
Base.permutedims(c::CubeMem,p)=CubeMem(c.axes[collect(p)],permutedims(c.data,p),permutedims(c.mask,p))
caxes(c::CubeMem)=c.axes
cubeproperties(c::CubeMem)=c.properties

Base.IndexStyle(::CubeMem)=Base.LinearFast()
Base.getindex(c::CubeMem,i::Integer)=iszero(c.mask[i] & 0x01) ? getindex(c.data,i) : missing
function Base.setindex!(c::CubeMem,i::Integer,v)
  if isa(v,Missing)
    setindex!(c.mask,i,c.mask[i] | 0x01)
  else
    setindex!(c.mask,i,c.mask[i] & 0xfe)
    setindex!(c.data,i,v)
  end
end
Base.size(c::CubeMem)=size(c.data)
Base.size(c::CubeMem,i)=size(c.data,i)
Base.similar(c::CubeMem)=cubeMem(c.axes,similar(c.data),copy(c.mask))
Base.ndims(c::CubeMem{T,N}) where {T,N}=N

getSingVal(c::CubeMem{T,N},i...;write::Bool=true) where {T,N}=(c.data[i...],c.mask[i...])
getSingVal(c::CubeMem{T,0};write::Bool=true) where {T}=(c.data[1],c.mask[1])
getSingVal(c::CubeAxis{T},i;write::Bool=true) where {T}=(c.values[i],nothing)

readCubeData(c::CubeMem)=c

function getSubRange(c::Tuple{AbstractArray{T,N},AbstractArray{UInt8,N}},i...;write::Bool=true) where {T,N}
  length(i)==N || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
  return (view(c[1],i...),view(c[2],i...))
end
getSubRange(c::Tuple{AbstractArray{T,0},AbstractArray{UInt8,0}};write::Bool=true) where {T}=c

"""
    gethandle(c::AbstractCubeData, [block_size])

Returns an indexable handle to the data.
"""
gethandle(c::AbstractCubeMem) = (c.data,c.mask)
gethandle(c::CubeAxis) = collect(c.values)
gethandle(c,block_size)=gethandle(c)


import ..ESDLTools.toRange
#Generic fallback method for _read
function _read(c::AbstractCubeData,thedata::Tuple,r::CartesianIndices)
  N=ndims(r)
  outar,outmask=thedata
  rr = convert(NTuple{N,UnitRange},r)
  h = gethandle(c,size(r))
  data,mask = getSubRange(h,rr...)
  copyto!(outar,data)
  copyto!(outmask,mask)
end

function _write(c::AbstractCubeData,thedata::Tuple,r::CartesianIndices)
  N=ndims(r)
  outar,outmask=thedata
  rr = convert(NTuple{N,UnitRange},r)
  h = gethandle(c,size(r))
  data,mask = getSubRange(h,rr...)
  copyto!(data,outar)
  copyto!(mask,outmask)
end
"This function creates a new view of the cube, joining longitude and latitude axes to a single spatial axis"
function mergeLonLat!(c::CubeMem)
ilon=findAxis(LonAxis,c.axes)
ilat=findAxis(LatAxis,c.axes)
ilat==ilon+1 || error("Lon and Lat axes must be consecutive to merge")
lonAx=c.axes[ilon]
latAx=c.axes[ilat]
newVals=Tuple{Float64,Float64}[(lonAx.values[i],latAx.values[j]) for i=1:length(lonAx), j=1:length(latAx)]
newAx=SpatialPointAxis(reshape(newVals,length(lonAx)*length(latAx)));
allNewAx=[c.axes[1:ilon-1];newAx;c.axes[ilat+1:end]];
s  = size(c.data)
s1 = s[1:ilon-1]
s2 = s[ilat+1:end]
newShape=(s1...,length(lonAx)*length(latAx),s2...)
CubeMem(allNewAx,reshape(c.data,newShape),reshape(c.mask,newShape))
end

#Implement getindex on AbstractCubeData objects
const IndR = Union{Integer,Colon,UnitRange}
getfirst(i::Integer,a::CubeAxis)=i
getlast(i::Integer,a::CubeAxis)=i
getfirst(i::UnitRange,a::CubeAxis)=first(i)
getlast(i::UnitRange,a::CubeAxis)=last(i)
getfirst(i::Colon,a::CubeAxis)=1
getlast(i::Colon,a::CubeAxis)=length(a)

function Base.getindex(c::AbstractCubeData,i::Integer...)
  length(i)==ndims(c) || error("You must provide $(ndims(c)) indices")
  r = CartesianIndices(CartesianIndex(i),CartesianIndex(i))
  aout = zeros(eltype(c),size(r))
  mout = fill(0xff,size(r))
  _read(c,(aout,mout),r)
  return ((mout[1] & 0x01)!=0x00) ? missing : aout[1]
end

function Base.getindex(c::AbstractCubeData,i::IndR...)
  length(i)==ndims(c) || error("You must provide $(ndims(c)) indices")
  ax = totuple(caxes(c))
  r = CartesianIndices(map((ii,iax)->getfirst(ii,iax):getlast(ii,iax),i,ax))
  aout = zeros(Union{eltype(c),Missing},size(r))
  mout = fill(0xff,size(r))
  _read(c,(aout,mout),r)
  squeezedims = totuple(findall(j->isa(j,Integer),i))
  dropdims(aout,dims=squeezedims)
  dropdims(mout,dims=squeezedims)
  #map!((m,v)->(m & 0x01)!=0x00 ? missing : v,aout,mout,aout)
  MaskArray(aout,mout)
end
Base.read(d::AbstractCubeData)=getindex(d,fill(Colon(),ndims(d))...)

function formatbytes(x)
  exts=["bytes","KB","MB","GB","TB"]
  i=1
  while x>=1024
    i=i+1
    x=x/1024
  end
  return string(round(x, digits=2)," ",exts[i])
end
cubesize(c::AbstractCubeData{T}) where {T}=(sizeof(T)+1)*prod(map(length,caxes(c)))
cubesize(c::AbstractCubeData{T,0}) where {T}=sizeof(T)+1

include("MmapCubes.jl")
#include("TempCubes.jl")
include("NetCDFCubes.jl")
#using .TempCubes
#handletype(::Union{AbstractTempCube,AbstractSubCube})=CacheHandle()

getCubeDes(c::AbstractSubCube)="Data Cube view"
#getCubeDes(c::TempCube)="Temporary Data Cube"
getCubeDes(c::CubeMem)="In-Memory data cube"
getCubeDes(c::EmptyCube)="Empty Data Cube (placeholder)"
function Base.show(io::IO,c::AbstractCubeData)
    println(io,getCubeDes(c), " with the following dimensions")
    for a in caxes(c)
        println(io,a)
    end
    foreach(cubeproperties(c)) do p
      println(io,p[1],": ",p[2])
    end
    println(io,"Total size: ",formatbytes(cubesize(c)))
end

import ..ESDL.workdir
using NetCDF
"""
    saveCube(cube,name::String)

Save a `MmapCube` or `CubeMem` to the folder `name` in the ESDL working directory.

See also loadCube, ESDLdir
"""
function saveCube(c::CubeMem{T},name::AbstractString) where T
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) alreaday exists, please pick another name")
  mkpath(newfolder)
  tc=Cubes.MmapCube(c.axes,folder=newfolder,T=T)
  dh,mh = Cubes.getmmaphandles(tc,mode="r+")
  copyto!(dh,c.data)
  copyto!(mh,c.mask)
end

import Base.Iterators: take, drop
Base.show(io::IO,a::RangeAxis)=print(io,rpad(Axes.axname(a),20," "),"Axis with ",length(a)," Elements from ",first(a.values)," to ",last(a.values))
function Base.show(io::IO,a::CategoricalAxis)
  print(io,rpad(Axes.axname(a),20," "), "Axis with elements: ")
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
Base.show(io::IO,a::SpatialPointAxis)=print(io,"Spatial points axis with ",length(a.values)," points")


include("TransformedCubes.jl")


end
