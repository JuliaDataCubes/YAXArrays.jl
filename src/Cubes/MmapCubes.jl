export MmapCube,getmmaphandles
import ..CABLABTools.totuple
using JLD
type MmapCube{T,N} <: AbstractCubeData{T,N}
  axes::Vector{CubeAxis}
  folder::String
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
  save(joinpath(folder,"axinfo.jld"),"axlist",axlist,"properties",properties)
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

function _read{N}(y::MmapCube,thedata::Tuple,r::CartesianRange{CartesianIndex{N}})
    dout,mout = thedata
    din,min   = getmmaphandles(y)
    for (i,ic) in enumerate(r)
        dout[i]=din[ic]
        mout[i]=min[ic]
    end
end
#function getSubRange{T,N}(c::MmapCube{T,N},i...;write::Bool=true)
#  length(i)==N || error("Wrong number of view arguments to getSubRange. Cube is: $c \n indices are $i")
#  return (view(c.handle[1],i...),view(c.handle[2],i...))
#end
Base.size(y::MmapCube)=ntuple(i->length(y.axes[i]),length(y.axes))
Base.size(y::MmapCube,i)=length(y.axes[i])
axes(y::MmapCube)=y.axes
getCubeDes(v::MmapCube)="Memory mapped cube"
