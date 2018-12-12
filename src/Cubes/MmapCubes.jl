export MmapCube,getmmaphandles
import ..ESDLTools.totuple
abstract type AbstractMmapCube{T,N}<:AbstractCubeData{T,N} end
using Serialization
using Distributed
using Mmap
using SentinelMissings
unmiss(::Type{Union{T,Missing}}) where T = T
unmiss(::Type{T}) where T = T
missval(::Type{T}) where T<: Integer = typemax(T)
missval(::Type{T}) where T<: AbstractFloat = convert(T,NaN)

"""
    MmapCube{T,N}

Defines a Memory-Mapped data cube which is stored on disk. Is generally returned
by mapCube applications.
"""
mutable struct MmapCube{T,N} <: AbstractMmapCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  persist::Bool
  properties::Dict{Any,Any}
end
mutable struct MmapCubePerm{T,N} <: AbstractMmapCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  perm::NTuple{N,Int}
  properties::Dict{Any,Any}
end
function cleanMmapCube(y::MmapCube)
  if !y.persist && myid()==1
    rm(y.folder,recursive=true)
  end
end
function MmapCube(axlist;folder=mktempdir(),T=Float32,persist::Bool=true,overwrite::Bool=false,properties=Dict{String,Any}())
  isdir(folder) || mkpath(folder)
  if !isempty(readdir(folder))
    if overwrite
      isfile(joinpath(folder,"axinfo.bin")) && rm(joinpath(folder,"axinfo.bin"))
      isfile(joinpath(folder,"data.bin")) && rm(joinpath(folder,"data.bin"))
    else
      error("Folder $folder is not empty, set overwrite=true to overwrite.")
    end
  end
  open(joinpath(folder,"axinfo.bin"),"w") do f
    serialize(f,axlist)
    serialize(f,properties)
    serialize(f,T)
  end
  s=map(length,axlist)
  open(f->write(f,fill(missval(unmiss(T)),s...)),joinpath(folder,"data.bin"),"w")
  ntc=MmapCube{T,length(axlist)}(axlist,folder,persist,properties)
  finalizer(cleanMmapCube,ntc)
  ntc
end
cubeproperties(c::MmapCube)=c.properties
getmmaphandles(y::MmapCube{T};mode="r") where T = getmmaphandles(y.folder,y.axes,T,mode=mode)
gethandle(y::MmapCube)=getmmaphandles(y)
iscompressed(::MmapCube)=false
iscompressed(::MmapCubePerm)=false
function getmmaphandles(folder, axlist,T;mode="r")

  s=map(length,axlist)
  ar = open(joinpath(folder,"data.bin"),mode) do fd
    Mmap.mmap(fd,Array{unmiss(T),length(axlist)},totuple(s))
  end
  as_sentinel(ar,missval(unmiss(T)))
end

function _write(y::MmapCube,thedata::AbstractArray,r::CartesianIndices{N}) where N
    cubeh   = getmmaphandles(y,mode="r+")
    for (i,ic) in enumerate(r)
        cubeh[ic]=thedata[i]
    end
end
function _read(y::MmapCube,thedata::AbstractArray,r::CartesianIndices{N}) where N
    cubeh   = getmmaphandles(y)
    for (i,ic) in enumerate(r)
        thedata[i]=cubeh[ic]
    end
end
@generated function Base.size(x::MmapCube{T,N}) where {T,N}
  :(@ntuple $N i->length(x.axes[i]))
end
@generated function Base.size(x::MmapCubePerm{T,N}) where {T,N}
  :(@ntuple $N i->length(x.axes[x.perm[i]]))
end
Base.size(x::Union{MmapCube,MmapCubePerm},i)=size(x)[i]
caxes(y::MmapCube)=y.axes
caxes(t::MmapCubePerm)=[t.axes[t.perm[i]] for i=1:length(t.axes)]
getCubeDes(v::MmapCube)="Memory mapped cube"
#Base.permutedims(c::MmapCube{T,N},perm) where {T,N}=MmapCubePerm{T,N}(c.axes,c.folder,perm,c.properties)
"""
    saveCube(c::AbstractCubeData, name::String)

Permanently saves a data cube to disk by either moving the folder out of the
tmp directory (for `TempCube`s) or by storing the data to disk (for `CubeMem`s)
"""
function saveCube(c::MmapCube,name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) already exists, please pick another name")
  # the julia cp implentation currently can only deal with files <2GB
  # the issue is:
  # https://github.com/JuliaLang/julia/issues/14574
  # mv(c.folder,newfolder)
  run(`mv $(c.folder) $(newfolder)`)
  c.folder=newfolder
  c.persist=true
end
export openmmapcube
function openmmapcube(folder;persist=true,axlist=nothing)
  axlist2,properties,T = open(joinpath(folder,"axinfo.bin")) do f
    (deserialize(f),deserialize(f),deserialize(f))
  end
  axlist == nothing && (axlist=axlist2)
  N=length(axlist)
  return MmapCube{T,length(axlist)}(axlist,folder,persist,properties)
end

"""
    loadCube(name::String)
Loads a cube that was previously saved with [`saveCube`](@ref). Returns a
`TempCube` object.
"""
function loadCube(name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) || error("$(name) does not exist")
  openmmapcube(newfolder)
end

"""
    rmCube(name::String)

Deletes a memory-mapped data cube.
"""
function rmCube(name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) || error("$(name) does not exist")
  rm(newfolder,recursive=true)
end
export rmCube
