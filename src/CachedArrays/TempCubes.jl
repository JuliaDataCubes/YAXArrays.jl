module TempCubes
export TempCube
using ..CubeAPI
"This defines a temporary datacube, written on disk which is usually "
type TempCube{T,N} <: AbstractCubeData{T}
  axes::Vector{CubeAxis}
  folder::UTF8String
  block_size::CartesianIndex{N}
end
CubeAPI.axes(t::TempCube)=t.axes
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
toRange(r::CartesianRange)=map(colon,r.start.I,r.stop.I)
toRange(c1::CartesianIndex,c2::CartesianIndex)=map(colon,c1.I,c2.I)

function readTempCube{N}(y::TempCube,data,mask,r::CartesianRange{CartesianIndex{N}})
  unit=CartesianIndex{N}()
  rsmall=CartesianRange(div(r.start-unit,y.block_size)+unit,div(r.stop-unit,y.block_size)+unit)
  for Ismall in rsmall
      bBig1=max((Ismall-unit).*y.block_size+unit,r.start)
      bBig2=min(Ismall.*y.block_size,r.stop)
      iToread=CartesianRange(bBig1-(Ismall-unit).*y.block_size,bBig2-(Ismall-unit).*y.block_size)
      filename=tofilename(Ismall)
      v=NetCDF.open(joinpath(y.folder,filename),"cube")
      vmask=NetCDF.open(joinpath(y.folder,filename),"mask")
      data[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=v[toRange(iToread)...]
      mask[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=vmask[toRange(iToread)...]
      ncclose()
  end
end

end
