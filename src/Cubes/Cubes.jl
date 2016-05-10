"""
The functions provided by CABLAB are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
export Axes, AbstractCubeData, getSubRange, readCubeData, AbstractCubeMem, axesCubeMem,CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis, axes,
       AbstractSubCube

"""
Supertype of all cubes. All map and plot functions are supposed to work on subtypes of these. This is done by implementing the following functions
"""
abstract AbstractCubeData{T}

"""
getSubRange reads some Cube data and writes it to a pre-allocated memory.
"""
getSubRange(c::AbstractCubeData,a...)=error("getSubrange called in the wrong way with argument types $(typof(c)), $(map(typeof,a))")

"""
This function reads a Cube's data and returns it to memory
"""
function readCubeData end

"""
This function calculates a subset of a cube's data
"""
function subsetCubeData end

"Returns the axes of a Cube"
axes(c::AbstractCubeData)=error("Axes function not implemented for $(typeof(c))")


"Supertype of all subtypes of the original data cube"
abstract AbstractSubCube{T} <: AbstractCubeData{T}


"Supertype of all in-memory representations of a data cube"
abstract AbstractCubeMem{T} <: AbstractCubeData{T}

include("Axes.jl")
importall .Axes

type CubeMem{T,N} <: AbstractCubeMem{T}
  axes::Vector{CubeAxis}
  data::Array{T,N}
  mask::Array{UInt8,N}
end
axes(c::CubeMem)=c.axes

Base.linearindexing(::CubeMem)=Base.LinearFast()
Base.getindex(c::CubeMem,i::Integer)=getindex(c.data,i)
Base.setindex!(c::CubeMem,i::Integer,v)=setindex!(c.data,i,v)
Base.size(c::CubeMem)=size(c.data)
Base.similar(c::CubeMem)=cubeMem(c.axes,similar(c.data),copy(c.mask))

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

include("TempCubes.jl")

end
