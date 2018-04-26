export MmapCube,getmmaphandles
import ..CABLABTools.totuple
using JLD
abstract type AbstractMmapCube{T,N}<:AbstractCubeData{T,N} end
type MmapCube{T,N} <: AbstractMmapCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  persist::Bool
  properties::Dict{Any,Any}
end
type MmapCubePerm{T,N} <: AbstractMmapCube{T,N}
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
      isfile(joinpath(folder,"axinfo.jld")) && rm(joinpath(folder,"axinfo.jld"))
      isfile(joinpath(folder,"data.bin")) && rm(joinpath(folder,"data.bin"))
      isfile(joinpath(folder,"mask.bin")) && rm(joinpath(folder,"mask.bin"))
    else
      error("Folder $folder is not empty, set overwrite=true to overwrite.")
    end
  end
  save(joinpath(folder,"axinfo.jld"),"axlist",axlist,"properties",properties,"eltype",T)
  s=map(length,axlist)
  open(f->write(f,zeros(T,s...)),joinpath(folder,"data.bin"),"w")
  open(f->write(f,zeros(UInt8,s...)),joinpath(folder,"mask.bin"),"w")
  ntc=MmapCube{T,length(axlist)}(axlist,folder,persist,properties)
  finalizer(ntc,cleanMmapCube)
  ntc
end

function getmmaphandles(y::MmapCube{T}) where T
  folder=y.folder
  axlist = y.axes
  s=map(length,axlist)
  ar = open(joinpath(folder,"data.bin"),"r+") do fd
    Mmap.mmap(fd,Array{T,length(axlist)},totuple(s))
  end
  ma = open(joinpath(folder,"mask.bin"),"r+") do fm
    Mmap.mmap(fm,Array{UInt8,length(axlist)},totuple(s))
  end
  ar,ma
end
gethandle(y::MmapCube)=getmmaphandles(y)
handletype(::MmapCube)=ViewHandle()

function _read{N}(y::MmapCube,thedata::Tuple,r::CartesianRange{CartesianIndex{N}})
    dout,mout = thedata
    din,min   = getmmaphandles(y)
    for (i,ic) in enumerate(r)
        dout[i]=din[ic]
        mout[i]=min[ic]
    end
end
@generated function Base.size{T,N}(x::MmapCube{T,N})
  :(@ntuple $N i->length(x.axes[i]))
end
@generated function Base.size{T,N}(x::MmapCubePerm{T,N})
  :(@ntuple $N i->length(x.axes[x.perm[i]]))
end
axes(y::MmapCube)=y.axes
axes(t::MmapCubePerm)=[t.axes[t.perm[i]] for i=1:length(t.axes)]
getCubeDes(v::MmapCube)="Memory mapped cube"
Base.permutedims{T,N}(c::MmapCube{T,N},perm)=MmapCubePerm{T,N}(c.axes,c.folder,perm,c.properties)
"""
    saveCube(c::AbstractCubeData, name::String)

Permanently saves a data cube to disk by either moving the folder out of the
tmp directory (for `TempCube`s) or by storing the data to disk (for `CubeMem`s)
"""
function saveCube(c::MmapCube,name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) already exists, please pick another name")
  mv(c.folder,newfolder)
  c.folder=newfolder
  c.persist=true
end
export openmmapcube
function openmmapcube(folder;persist=true,axlist=nothing)
  axlist == nothing && (axlist=load(joinpath(folder,"axinfo.jld"),"axlist"))
  properties=try
      load(joinpath(folder,"axinfo.jld"),"properties")
    catch
      Dict{String,Any}()
    end
    T = load(joinpath(folder,"axinfo.jld"),"eltype")
  N=length(axlist)
  return MmapCube{T,length(axlist)}(axlist,folder,persist,properties)
end
