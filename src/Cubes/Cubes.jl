"""
The functions provided by ESDL are supposed to work on different types of cubes. This module defines the interface for all
Data types that
"""
module Cubes
export Axes, AbstractCubeData, getSubRange, readcubedata, AbstractCubeMem, axesCubeMem,CubeAxis, TimeAxis, TimeHAxis, QuantileAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis, caxes,
       AbstractSubCube, CubeMem, EmptyCube, YearStepRange, _read, saveCube, loadCube, RangeAxis, CategoricalAxis, axVal2Index, MSCAxis,
       getSingVal, ScaleAxis, axname, @caxis_str, rmCube, cubeproperties, findAxis, AxisDescriptor, get_descriptor, ByName, ByType, ByValue, ByFunction, getAxis,
       getOutAxis, Cube, (..), getCubeData, subsetcube, CubeMask, renameaxis!, Dataset, S3Cube, cubeinfo
import DiskArrays
import Distributed: myid

"""
    AbstractCubeData{T,N}

Supertype of all cubes. `T` is the data type of the cube and `N` the number of
dimensions. Beware that an `AbstractCubeData` does not implement the `AbstractArray`
interface. However, the `ESDL` functions [`mapCube`](@ref), [`reduceCube`](@ref),
[`readcubedata`](@ref), [`plotMAP`](@ref) and [`plotXY`](@ref) will work on any subtype
of `AbstractCubeData`
"""
abstract type AbstractCubeData{T,N} end

"""
getSingVal reads a single point from the cube's data
"""
getSingVal(c::AbstractCubeData,a...)=error("getSingVal called in the wrong way with argument types $(typeof(c)), $(map(typeof,a))")

Base.eltype(::AbstractCubeData{T}) where T = T
Base.ndims(::AbstractCubeData{<:Any,N}) where N = N

"""
    readCubeData(cube::AbstractCubeData)

Given any type of `AbstractCubeData` returns a [`CubeMem`](@ref) from it.
"""
function readcubedata(x::AbstractCubeData{T,N}) where {T,N}
  s=size(x)
  aout = zeros(Union{T,Missing},s...)
  r=CartesianIndices(s)
  _read(x,aout,r)
  CubeMem(collect(CubeAxis,caxes(x)),aout,cubeproperties(x))
end

"""
This function calculates a subset of a cube's data
"""
function subsetcube end

function _read end

getsubset(x::AbstractCubeData) = x.subset === nothing ? ntuple(i->Colon(),ndims(x)) : x.subset
#"""
#Internal function to read a range from a datacube
#"""
#_read(c::AbstractCubeData,d,r::CartesianRange)=error("_read not implemented for $(typeof(c))")

"Returns the axes of a Cube"
caxes(c::AbstractCubeData)=error("Axes function not implemented for $(typeof(c))")

cubeproperties(::AbstractCubeData)=Dict{String,Any}()

"Chunks, if given"
cubechunks(c::AbstractCubeData) = (size(c,1),map(i->1,2:ndims(c))...)

"Offset of the first chunk"
chunkoffset(c::AbstractCubeData) = ntuple(i->0,ndims(c))

function iscompressed end

"Supertype of all subtypes of the original data cube"
abstract type AbstractSubCube{T,N} <: AbstractCubeData{T,N} end


"Supertype of all in-memory representations of a data cube"
abstract type AbstractCubeMem{T,N} <: AbstractCubeData{T,N} end

include("Axes.jl")
using .Axes
import .Axes: getAxis
struct EmptyCube{T}<:AbstractCubeData{T,0} end
caxes(c::EmptyCube)=CubeAxis[]


mutable struct CleanMe
  path::String
  persist::Bool
  function CleanMe(path::String,toclean::Bool)
    c = new(path,toclean)
    finalizer(clean,c)
    c
  end
end
function clean(c::CleanMe)
  if !c.persist && myid()==1
    if !isdir(c.path)
      @warn "Cube directory $(c.path) does not exist. Can not clean"
    else
      rm(c.path,recursive=true)
    end
  end
end

"""
    ESDLArray{T,N} <: AbstractCubeMem{T,N}

An in-memory data cube. It is returned by applying `mapCube` when
the output cube is small enough to fit in memory or by explicitly calling
[`readCubeData`](@ref) on any type of cube.

### Fields

* `axes` a `Vector{CubeAxis}` containing the Axes of the Cube
* `data` N-D array containing the data

"""
struct ESDLArray{T,N,A<:AbstractArray{T,N},AT} <: AbstractCubeData{T,N}
  axes::AT
  data::A
  properties::Dict{String}
  cleaner::Union{CleanMe,Nothing}
end

ESDLArray(axes,data,properties=Dict{String,Any}(); cleaner=nothing) = ESDLArray(axes,data,properties, cleaner)
Base.size(a::ESDLArray) = size(a.data)
Base.size(a::ESDLArray,i::Int) = size(a.data,i)
Base.permutedims(c::ESDLArray,p)=ESDLArray(c.axes[collect(p)],permutedims(c.data,p),c.properties)
caxes(c::ESDLArray)=c.axes
cubeproperties(c::ESDLArray)=c.properties
iscompressed(c::ESDLArray)=iscompressed(c.data)
iscompressed(c::DiskArrays.PermutedDiskArray) = iscompressed(c.a.parent)
iscompressed(c::DiskArrays.SubDiskArray) = iscompressed(c.v.parent)
iscompressed(c::Array) = false
cubechunks(c::ESDLArray)=common_size(eachchunk(c.data))
common_size(a::DiskArrays.GridChunks) = a.chunksize
function common_size(a)
  ntuple(ndims(a)) do idim
    otherdims = setdiff(1:ndims(a),idim)
    allengths = map(i->length(i.indices[idim]),a)
    for od in otherdims
      allengths = unique(allengths,dims=od)
    end
    @assert length(allengths) == size(a,idim)
    length(allengths)<3 ? allengths[1] : allengths[2]
  end
end

chunkoffset(c::ESDLArray)=common_offset(eachchunk(c.data))
common_offset(a::DiskArrays.GridChunks) = a.offset
function common_offset(a)
  ntuple(ndims(a)) do idim
    otherdims = setdiff(1:ndims(a),idim)
    allengths = map(i->length(i[idim]),a)
    for od in otherdims
      allengths = unique(allengths,dims=od)
    end
    @assert length(allengths) == size(a,idim)
    length(allengths)<3 ? 0 : allengths[2]-allengths[1]
  end
end
readcubedata(c::ESDLArray)=ESDLArray(c.axes,Array(c.data),c.properties,nothing)

# function getSubRange(c::AbstractArray,i...;write::Bool=true)
#   length(i)==ndims(c) || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
#   return view(c,i...)
# end
# getSubRange(c::Tuple{AbstractArray{T,0},AbstractArray{UInt8,0}};write::Bool=true) where {T}=c

function _subsetcube end

function subsetcube(z::ESDLArray{T};kwargs...) where T
  newaxes, substuple = _subsetcube(z,collect(Any,map(Base.OneTo,size(z)));kwargs...)
  newdata = view(z.data,substuple...)
  ESDLArray(newaxes,newdata,z.properties,cleaner = z.cleaner)
end

# """
#     gethandle(c::AbstractCubeData, [block_size])
#
# Returns an indexable handle to the data.
# """
# gethandle(c::AbstractCubeMem) = c.data
# gethandle(c::CubeAxis) = collect(c.values)
# gethandle(c,block_size)=gethandle(c)

function Base.getindex(c::AbstractCubeData,i...)
  c.data[i...]
end
Base.read(d::AbstractCubeData) = getindex(d,fill(Colon(),ndims(d))...)

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

getCubeDes(c::AbstractSubCube)="Data Cube view"
getCubeDes(::CubeAxis)="Cube axis"
getCubeDes(c::ESDLArray)="ESDL data cube"
getCubeDes(c::EmptyCube)="Empty Data Cube (placeholder)"
function Base.show(io::IO,c::AbstractCubeData)
    println(io,getCubeDes(c), " with the following dimensions")
    for a in caxes(c)
        println(io,a)
    end

    foreach(cubeproperties(c)) do p
      if p[1] in ("labels","name","units")
        println(io,p[1],": ",p[2])
      end
    end
    println(io,"Total size: ",formatbytes(cubesize(c)))
end

import ..ESDL.workdir
using NetCDF

function check_overwrite(newfolder, overwrite)
  if isdir(newfolder)
    if overwrite
      rm(newfolder, recursive=true)
    else
      error("$(newfolder) already exists, please pick another name or use `overwrite=true`")
    end
  end
end
function getsavefolder(name)
  if isempty(name)
    name = tempname()[2:end]
  end
  isabspath(name) ? name : joinpath(workdir[],name)
end

"""
    saveCube(cube,name::String)

Save a [`ZarrCube`](@ref) or [`CubeMem`](@ref) to the folder `name` in the ESDL working directory.

See also [`loadCube`](@ref)
"""
function saveCube end


# function saveCube(c::CubeMem{T},name::AbstractString; overwrite=true) where T
#   newfolder=getsavefolder(name)
#   check_overwrite(newfolder, overwrite)
#   tc=Cubes.ESDLZarr.ZArrayCube(c.axes,folder=newfolder,T=T)
#   _write(tc,c.data,CartesianIndices(c.data))
# end

import Base.Iterators: take, drop
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
Base.show(io::IO,a::SpatialPointAxis)=print(io,"Spatial points axis with ",length(a.values)," points")

include("TransformedCubes.jl")
function S3Cube end
include("ZarrCubes.jl")
import .ESDLZarr: (..), Cube, getCubeData, loadCube, rmCube, CubeMask, cubeinfo

include("NetCDFCubes.jl")
include("Datasets.jl")
import .Datasets: Dataset, ESDLDataset
include("OBS.jl")
end
