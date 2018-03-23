export MmapCube
import ..CABLABTools.totuple
using JLD
type MmapCube{T,N} <: AbstractCubeData{T,N}
  axes::Vector{CubeAxis}
  folder::String
  handle::Tuple{Array{T,N},Array{UInt8,N}}
  persist::Bool
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
  s=map(length,axlist)
  fd = open(joinpath(folder,"data.bin"),"w+")
  fm = open(joinpath(folder,"mask.bin"),"w+")
  ar = Mmap.mmap(fd,Array{T,length(axlist)},totuple(s))
  ma = Mmap.mmap(fm,Array{UInt8,length(axlist)},totuple(s))
  save(joinpath(folder,"axinfo.jld"),"axlist",axlist,"properties",properties)
  ntc=MmapCube{T,length(axlist)}(axlist,folder,(ar,ma),persist,properties)
  finalizer(ntc,cleanMmapCube)
  ntc
end

function _read{N}(y::MmapCube,thedata::Tuple,r::CartesianRange{CartesianIndex{N}})
    dout,mout = thedata
    din,min   = y.handle
    for (i,ic) in enumerate(r)
        dout[i]=din[ic]
        mout[i]=min[ic]
    end
end
function getSubRange{T,N}(c::MmapCube{T,N},i...;write::Bool=true)
  length(i)==N || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
  return (view(c.handle[1],i...),view(c.handle[2],i...))
end
Base.size(y::MmapCube)=size(y.handle[1])
Base.size(y::MmapCube,i)=size(y.handle[1],i)
axes(y::MmapCube)=y.axes
getCubeDes(v::MmapCube)="Memory mapped cube"
