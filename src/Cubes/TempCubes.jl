module TempCubes
export TempCube, openTempCube, TempCubePerm, saveCube, loadCube
importall ..Cubes
importall ...CABLABTools

"This defines a temporary datacube, written on disk which is usually "
abstract AbstractTempCube{T,N} <: AbstractCubeData{T,N}

"""
    type TempCube{T,N} <: AbstractCubeData{T,N}

The main data structure for storing temporary results from cube operations. Is
usually returned by [`mapCube`](@ref), if the result is larger than `max_cache`

### Fields

* `axes` a vector of [`CubeAxis`](@ref) containing the axes
* `folder` folder containing the data
* `block_size` dimension of the files that the cube is split into

Each `TempCube` is stored in a single `folder`, but can contain several files. The
rule is that one file is small enough to be read into memory and the `block_size`
determines the size and shape of each sub-file. This data structure is quite convenient
for parrallel access, because different processes can write their results at the same
time.
"""
type TempCube{T,N} <: AbstractTempCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  block_size::CartesianIndex{N}
  persist::Bool
end
"This defines a perumtation of a temporary datacube, as a result from perumtedims on a TempCube"
type TempCubePerm{T,N} <: AbstractTempCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  block_size::CartesianIndex{N}
  perm::NTuple{N,Int}
end


axes(t::AbstractTempCube)=t.axes
axes(t::TempCubePerm)=[t.axes[t.perm[i]] for i=1:length(t.axes)]
using Base.Cartesian
using NetCDF
totuple(x::Vector)=ntuple(i->x[i],length(x))
tofilename(ii::CartesianIndex)=string("file",join(map(string,ii.I),"_"),".nc")
Base.ndims{T,N}(x::AbstractTempCube{T,N})=N
Base.eltype{T}(x::AbstractTempCube{T})=T
@generated function Base.size{T,N}(x::TempCube{T,N})
  :(@ntuple $N i->length(x.axes[i]))
end
@generated function Base.size{T,N}(x::TempCubePerm{T,N})
  :(@ntuple $N i->length(x.axes[x.perm[i]]))
end

using JLD

function TempCube{N}(axlist,block_size::CartesianIndex{N};folder=mktempdir(),T=Float32,persist=true)
  s=map(length,axlist)
  ssmall=map(div,s,block_size.I)
  for ii in CartesianRange(totuple(ssmall))
    istart = ((ii-CartesianIndex{N}()).*block_size)+CartesianIndex{N}()
    ncdims = NcDim[NcDim(axlist[i],istart[i],block_size[i]) for i=1:N]
    vars   = NcVar[NcVar("cube",ncdims,t=T),NcVar("mask",ncdims,t=UInt8)]
    nc     = NetCDF.create(joinpath(folder,tofilename(ii)),vars)
    NetCDF.close(nc)
  end
  save(joinpath(folder,"axinfo.jld"),"axlist",axlist)
  ntc=TempCube{T,N}(axlist,folder,block_size,persist)
  finalizer(ntc,cleanTempCube)
  return ntc
end

function openTempCube(folder;persist=true)
  axlist=load(joinpath(folder,"axinfo.jld"),"axlist")
  N=length(axlist)
  v=NetCDF.open(joinpath(folder,tofilename(CartesianIndex{N}())),"cube")
  T=eltype(v)
  block_size=CartesianIndex(size(v))
  ncclose(joinpath(folder,tofilename(CartesianIndex{N}())))
  return TempCube{T,N}(axlist,folder,block_size,persist)
end

function readCubeData{T}(y::AbstractTempCube{T})
  s=map(length,y.axes)
  data=zeros(T,s...)
  mask=zeros(UInt8,s...)
  _read(y,(data,mask),CartesianRange(totuple(s)))
  CubeMem(y.axes,data,mask)
end

function cleanTempCube(y::TempCube)
  if !y.persist && myid()==1
    f=readdir(y.folder)
    filter!(i->startswith(i,"file"),f)
    for fi in f
      fn=joinpath(y.folder,fi)
      haskey(NetCDF.currentNcFiles,abspath(fn)) && ncclose(fn)
    end
    rm(y.folder,recursive=true)
  end
end

function _read{N}(y::TempCube,thedata::NTuple{2},r::CartesianRange{CartesianIndex{N}})
  data,mask=thedata
  unit=CartesianIndex{N}()
  rsmall=CartesianRange(div(r.start-unit,y.block_size)+unit,div(r.stop-unit,y.block_size)+unit)
  for Ismall in rsmall
      bBig1=max((Ismall-unit).*y.block_size+unit,r.start)
      bBig2=min(Ismall.*y.block_size,r.stop)
      iToread=CartesianRange(bBig1-(Ismall-unit).*y.block_size,bBig2-(Ismall-unit).*y.block_size)
      filename=joinpath(y.folder,tofilename(Ismall))
      v=NetCDF.open(filename,"cube")
      vmask=NetCDF.open(filename,"mask")
      data[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=v[toRange(iToread)...]
      mask[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=vmask[toRange(iToread)...]
      ncclose(filename)
  end
  return nothing
end

Base.permutedims{T,N}(c::TempCube{T,N},perm)=TempCubePerm{T,N}(c.axes,c.folder,c.block_size,perm)
#Method for reading cubes that get transposed
#Per means fileOrder -> MemoryOrder
function _read{N}(y::TempCubePerm,thedata::NTuple{2},r::CartesianRange{CartesianIndex{N}})
  data,mask=thedata
  perm=y.perm
  blocksize_trans = CartesianIndex(ntuple(i->y.block_size.I[perm[i]],N))
  iperm=getiperm(perm)
  unit=CartesianIndex{N}()
  rsmall=CartesianRange(div(r.start-unit,blocksize_trans)+unit,div(r.stop-unit,blocksize_trans)+unit)
  for Ismall in rsmall
      bBig1=max((Ismall-unit).*blocksize_trans+unit,r.start)
      bBig2=min(Ismall.*blocksize_trans,r.stop)
      iToread=CartesianRange(bBig1-(Ismall-unit).*blocksize_trans,bBig2-(Ismall-unit).*blocksize_trans)
      filename=joinpath(y.folder,tofilename(CartesianIndex(ntuple(i->Ismall.I[iperm[i]],N))))
      v0=NetCDF.open(filename,"cube")
      vmask0=NetCDF.open(filename,"mask")
      v=NetCDF.readvar(v0,toRange(iToread)[iperm]...)
      vmask=NetCDF.readvar(vmask0,toRange(iToread)[iperm]...)
      mypermutedims!(view(data,toRange(bBig1-r.start+unit,bBig2-r.start+unit)...),v,Val{perm})
      mypermutedims!(view(mask,toRange(bBig1-r.start+unit,bBig2-r.start+unit)...),vmask,Val{perm})
      ncclose(filename)
  end
  return nothing
end

import ...CABLAB.workdir
function saveCube(c::TempCube,name::AbstractString)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) alreaday exists, please pick another name")
  mv(c.folder,newfolder)
  c.folder=newfolder
  c.persist=true
end

function loadCube(name::AbstractString)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) || error("$(name) does not exist")
  openTempCube(newfolder)
end

end #module
