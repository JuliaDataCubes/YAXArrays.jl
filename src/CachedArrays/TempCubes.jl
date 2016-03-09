module TempCubes
export TempCube
using ..CubeAPI
"This defines a temporary datacube, written on disk which is usually "
type TempCube{T,N} <: AbstractCubeData{T}
  axes::Vector{CubeAxis}
  folder::UTF8String
  block_size::CartesianIndex{N}
end
using Base.Cartesian
using NetCDF
totuple(x::Vector)=ntuple(i->x[i],length(x))
tofilename(ii::CartesianIndex)=string("file",join(map(string,ii.I),"_"),".nc")
Base.ndims{T,N}(x::TempCube{T,N})=N
Base.eltype{T}(x::TempCube{T})=T
@generated function Base.size{T,N}(x::TempCube{T,N})
  :(@ntuple $N i->length(x.axes[i]))
end

function TempCube{N}(axlist,block_size::CartesianIndex{N};folder=mktempdir(),T=Float32)
  s=map(length,axlist)
  ssmall=map(div,s,block_size.I)
  for ii in CartesianRange(totuple(ssmall))
    istart = ((ii-CartesianIndex{N}()).*block_size)+CartesianIndex{N}()
    ncdims = NcDim[NcDim(axlist[i],istart[i],block_size[i]) for i=1:N]
    vars   = NcVar[NcVar("cube",ncdims,t=T),NcVar("mask",ncdims,t=UInt8)]
    nc     = NetCDF.create(joinpath(folder,tofilename(ii)),vars)
    NetCDF.close(nc)
  end
  return TempCube{T,N}(axlist,folder,block_size)
end




end
