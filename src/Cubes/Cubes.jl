"""
The functions provided by CABLAB are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
export Axes, AbstractCubeData, getSubRange, readCubeData, AbstractCubeMem, axesCubeMem,CubeAxis, TimeAxis, TimeHAxis, QuantileAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis, axes,
       AbstractSubCube, CubeMem, openTempCube, EmptyCube, YearStepRange, _read, saveCube, loadCube, RangeAxis, CategoricalAxis, axVal2Index, MSCAxis,
       getSingVal, TimeScaleAxis, axname, @caxis_str, rmCube, cubeproperties, findAxis, AxisDescriptor, get_descriptor, ByName, ByType, ByValue, ByFunction, getAxis,
       getOutAxis, needshandle, AbstractTempCube, gethandle, handletype, getcachehandle

"""
    AbstractCubeData{T,N}

Supertype of all cubes. `T` is the data type of the cube and `N` the number of
dimensions. Beware that an `AbstractCubeData` does not implement the `AbstractArray`
interface. However, the `CABLAB` functions [mapCube](@ref), [reduceCube](@ref),
[readCubeData](@ref), [plotMAP](@ref) and [plotXY](@ref) will work on any subtype
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
function readCubeData{T,N}(x::AbstractCubeData{T,N})
  s=size(x)
  aout,mout=zeros(T,s...),zeros(UInt8,s...)
  r=CartesianRange(CartesianIndex{N}(),CartesianIndex(s...))
  _read(x,(aout,mout),r)
  CubeMem(collect(CubeAxis,axes(x)),aout,mout)
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
axes(c::AbstractCubeData)=error("Axes function not implemented for $(typeof(c))")

"Number of dimensions"
Base.ndims{T,N}(::AbstractCubeData{T,N})=N

cubeproperties(::AbstractCubeData)=Dict{String,Any}()

"Supertype of all subtypes of the original data cube"
abstract type AbstractSubCube{T,N} <: AbstractCubeData{T,N} end


"Supertype of all in-memory representations of a data cube"
abstract type AbstractCubeMem{T,N} <: AbstractCubeData{T,N} end

include("Axes.jl")
importall .Axes

immutable EmptyCube{T}<:AbstractCubeData{T,0} end
axes(c::EmptyCube)=CubeAxis[]

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
type CubeMem{T,N} <: AbstractCubeMem{T,N}
  axes::Vector{CubeAxis}
  data::Array{T,N}
  mask::Array{UInt8,N}
  properties::Dict{String}
end

CubeMem(axes::Vector{CubeAxis},data,mask) = CubeMem(axes,data,mask,Dict{String,Any}())
Base.permutedims(c::CubeMem,p)=CubeMem(c.axes[collect(p)],permutedims(c.data,p),permutedims(c.mask,p))
axes(c::CubeMem)=c.axes
cubeproperties(c::CubeMem)=c.properties

Base.IndexStyle(::CubeMem)=Base.LinearFast()
Base.getindex(c::CubeMem,i::Integer)=getindex(c.data,i)
Base.setindex!(c::CubeMem,i::Integer,v)=setindex!(c.data,i,v)
Base.size(c::CubeMem)=size(c.data)
Base.size(c::CubeMem,i)=size(c.data,i)
Base.similar(c::CubeMem)=cubeMem(c.axes,similar(c.data),copy(c.mask))
Base.ndims{T,N}(c::CubeMem{T,N})=N

getSingVal{T,N}(c::CubeMem{T,N},i...;write::Bool=true)=(c.data[i...],c.mask[i...])
getSingVal{T}(c::CubeMem{T,0};write::Bool=true)=(c.data[1],c.mask[1])
getSingVal{T}(c::CubeAxis{T},i;write::Bool=true)=(c.values[i],nothing)

readCubeData(c::CubeMem)=c

function getSubRange{T,N}(c::Tuple{AbstractArray{T,N},AbstractArray{UInt8,N}},i...;write::Bool=true)
  length(i)==N || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
  return (view(c[1],i...),view(c[2],i...))
end
getSubRange{T}(c::Tuple{AbstractArray{T,0},AbstractArray{UInt8,0}};write::Bool=true)=c

"""
    gethandle(c::AbstractCubeData, [block_size])

Returns an indexable handle to the data.
"""
gethandle(c::AbstractCubeMem) = (c.data,c.mask)
gethandle(c::CubeAxis) = collect(c.values)
gethandle(c,block_size)=gethandle(c)
function getcachehandle end

immutable ViewHandle end
immutable CacheHandle end
handletype(::AbstractCubeMem)=ViewHandle()


import ..CABLABTools.toRange
#Generic fallback method for _read
function _read{N}(c::AbstractCubeData,thedata::Tuple,r::CartesianRange{N})
  outar,outmask=thedata
  rr = convert(NTuple{N,UnitRange},r)
  h = gethandle(c,size(r))
  data,mask = getSubRange(h,rr...)
  copy!(outar,data)
  copy!(outmask,mask)
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

function formatbytes(x)
  exts=["bytes","KB","MB","GB","TB"]
  i=1
  while x>=1024
    i=i+1
    x=x/1024
  end
  return string(round(x,2)," ",exts[i])
end
cubesize{T}(c::AbstractCubeData{T})=(sizeof(T)+1)*prod(map(length,axes(c)))
cubesize{T}(c::AbstractCubeData{T,0})=sizeof(T)+1

include("MmapCubes.jl")
include("TempCubes.jl")
include("NetCDFCubes.jl")
importall .TempCubes
handletype(::Union{AbstractTempCube,AbstractSubCube})=CacheHandle()


getCubeDes(c::AbstractSubCube)="Data Cube view"
getCubeDes(c::TempCube)="Temporary Data Cube"
getCubeDes(c::CubeMem)="In-Memory data cube"
getCubeDes(c::EmptyCube)="Empty Data Cube (placeholder)"
function Base.show(io::IO,c::AbstractCubeData)
    println(io,getCubeDes(c), " with the following dimensions")
    for a in axes(c)
        println(io,a)
    end
    foreach(c.properties) do p
      println(io,p[1],": ",p[2])
    end
    println(io,"Total size: ",formatbytes(cubesize(c)))
end

import ..CABLAB.workdir
using NetCDF
"""
    saveCube(cube,name::String)

Save a `TempCube` or `CubeMem` to the folder `name` in the CABLAB working directory.

See also loadCube, CABLABdir
"""
function saveCube{T}(c::CubeMem{T},name::AbstractString)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) alreaday exists, please pick another name")
  mkpath(newfolder)
  tc=Cubes.TempCube(c.axes,CartesianIndex(size(c)),folder=newfolder,T=T)
  files=readdir(newfolder)
  filter!(i->startswith(i,"file"),files)
  @assert length(files)==1
  ncwrite(c.data,joinpath(newfolder,files[1]),"cube")
  ncwrite(c.mask,joinpath(newfolder,files[1]),"mask")
  ncclose(joinpath(newfolder,files[1]))
end


Base.show(io::IO,a::RangeAxis)=print(io,rpad(Axes.axname(a),20," "),"Axis with ",length(a)," Elements from ",first(a.values)," to ",last(a.values))
function Base.show(io::IO,a::CategoricalAxis)
    print(io,rpad(Axes.axname(a),20," "), "Axis with elements: ")
    for v in a.values
        print(io,v," ")
    end
end
Base.show(io::IO,a::SpatialPointAxis)=print(io,"Spatial points axis with ",length(a.values)," points")


include("TransformedCubes.jl")


end
