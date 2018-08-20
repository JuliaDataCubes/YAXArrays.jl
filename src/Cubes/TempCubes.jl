module TempCubes
export TempCube, openTempCube, TempCubePerm, loadCube,rmCube, AbstractTempCube
importall ..Cubes
importall ...ESDLTools
import ....ESDL.ESDLdir

"This defines a temporary datacube, written on disk which is usually "
abstract type AbstractTempCube{T,N} <: AbstractCubeData{T,N} end

"""
    type TempCube{T,N} <: AbstractCubeData{T,N}

The main data structure for storing temporary results from cube operations. Is
usually returned by [mapCube](@ref), if the result is larger than `max_cache`

### Fields

* `axes` a vector of [CubeAxis](@ref) containing the axes
* `folder` folder containing the data
* `block_size` dimension of the files that the cube is split into

Each `TempCube` is stored in a single `folder`, but can contain several files. The
rule is that one file is small enough to be read into memory and the `block_size`
determines the size and shape of each sub-file. This data structure is quite convenient
for parrallel access, because different processes can write their results at the same
time.
"""
mutable struct TempCube{T,N} <: AbstractTempCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  block_size::CartesianIndex{N}
  persist::Bool
  properties::Dict{String}
end
"This defines a perumtation of a temporary datacube, as a result from perumtedims on a TempCube"
mutable struct TempCubePerm{T,N} <: AbstractTempCube{T,N}
  axes::Vector{CubeAxis}
  folder::String
  block_size::CartesianIndex{N}
  perm::NTuple{N,Int}
  properties::Dict{String}
end



axes(t::AbstractTempCube)=t.axes
axes(t::TempCubePerm)=[t.axes[t.perm[i]] for i=1:length(t.axes)]
cubeproperties(t::AbstractTempCube)=t.properties
using Base.Cartesian
using NetCDF
totuple(x::Vector)=ntuple(i->x[i],length(x))
tofilename(ii::CartesianIndex)=string("file",join(map(string,ii.I),"_"),".nc")
Base.ndims(x::AbstractTempCube{T,N}) where {T,N}=N
Base.eltype(x::AbstractTempCube{T}) where {T}=T
@generated function Base.size(x::TempCube{T,N}) where {T,N}
  :(@ntuple $N i->length(x.axes[i]))
end
@generated function Base.size(x::TempCubePerm{T,N}) where {T,N}
  :(@ntuple $N i->length(x.axes[x.perm[i]]))
end

using JLD

"""
    TempCube(axlist, block_size)

Creates a new temporary Data Cube with the axes specified by `axlist`, a Vector{CubeAxis}. `block_size` is a Tuple
containing the dimensions of each sub-file the cube is split into.

### Keyword arguments

- `folder=mktempdir()` a folder where the new Cube is stored
- `T=Float32` the cubes data type
- `persist=true` shall the cubes disk representation be kept or deleted when the cube gets out of scope
- `overwrite=false` shall the data in an existing folder be overwritten
"""
function TempCube(axlist,block_size::CartesianIndex{N};folder=mktempdir(),T=Float32,persist::Bool=true,overwrite::Bool=false,properties=Dict{String,Any}()) where N
  isdir(folder) || mkpath(folder)
  if !isempty(readdir(folder))
    if overwrite
      isfile(joinpath(folder,"axinfo.jld")) && rm(joinpath(folder,"axinfo.jld"))
      ncfiles=filter(f->endswith(f,".nc") && startswith(f,"file_"),readdir(folder))
      foreach(ncfiles) do f
        rm(joinpath(folder,f))
      end
    else
      error("Folder $folder is not empty, set overwrite=true to overwrite.")
    end
  end
  s=map(length,axlist)
  ssmall=map(div,s,block_size.I)
  for ii in CartesianIndices(totuple(ssmall))
    istart = (CItimes((ii-CartesianIndex{N}()),block_size))+CartesianIndex{N}()
    ncdims = N>0 ? NcDim[NcDim(axlist[i],istart[i],block_size[i]) for i=1:N] : [NcDim("DummyDim",1)]
    vars   = NcVar[NcVar("cube",ncdims,t=T),NcVar("mask",ncdims,t=UInt8)]
    nc     = NetCDF.create(joinpath(folder,tofilename(ii)),vars)
#    NetCDF.putvar(nc["cube"],fill(iniVal,block_size))
#    NetCDF.putvar(nc["mask"],fill(MISSING,block_size))
    NetCDF.close(nc)
  end
  save(joinpath(folder,"axinfo.jld"),"axlist",axlist,"properties",properties)
  ntc=TempCube{T,N}(axlist,folder,block_size,persist,properties)
  finalizer(ntc,cleanTempCube)
  return ntc
end

TempCube(axlist,block_size::Tuple;kwargs...)=TempCube(axlist,CartesianIndex(block_size);kwargs...)

function openTempCube(folder;persist=true,axlist=nothing)

  axlist == nothing && (axlist=load(joinpath(folder,"axinfo.jld"),"axlist"))
  properties=try
      load(joinpath(folder,"axinfo.jld"),"properties")
    catch
      Dict{String,Any}()
    end
  N=length(axlist)
  v=NetCDF.open(joinpath(folder,tofilename(CartesianIndex{N}())),"cube")
  T=eltype(v)
  block_size= N==0 ? CartesianIndex(()) : CartesianIndex(size(v))
  ncclose(joinpath(folder,tofilename(CartesianIndex{N}())))
  return TempCube{T,N}(axlist,folder,block_size,persist,properties)
end

function readCubeData(y::AbstractTempCube{T}) where T
  s=map(length,y.axes)
  data=zeros(T,s...)
  mask=zeros(UInt8,s...)
  _read(y,(data,mask),CartesianIndices(totuple(s)))
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

function rmCube(f::String)
  if isdir(joinpath(ESDLdir(),f))
    if any(i->basename(i)=="data.bin",readdir(joinpath(ESDLdir(),f)))
      rm(joinpath(ESDLdir(),f),recursive=true)
    else
      y=openTempCube(joinpath(ESDLdir(),f),persist=false)
      cleanTempCube(y)
    end
  end
end

function _read(y::TempCube,thedata::Tuple,r::CartesianIndices{CartesianIndex{N}}) where N
  data,mask=thedata
  unit=CartesianIndex{N}()
  rsmall=CartesianIndices(CIdiv(r.start-unit,y.block_size)+unit,CIdiv(r.stop-unit,y.block_size)+unit)
  for Ismall in rsmall
      bBig1=max(CItimes((Ismall-unit),y.block_size)+unit,r.start)
      bBig2=min(CItimes(Ismall,y.block_size),r.stop)
      iToread=CartesianIndices(bBig1-CItimes((Ismall-unit),y.block_size),bBig2-CItimes((Ismall-unit),y.block_size))
      filename=joinpath(y.folder,tofilename(Ismall))
      v=NetCDF.open(filename,"cube")
      vmask=NetCDF.open(filename,"mask")
      data[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=v[toRange(iToread)...]
      mask[toRange(bBig1-r.start+unit,bBig2-r.start+unit)...]=vmask[toRange(iToread)...]
      ncclose(filename)
  end
  return nothing
end

Base.permutedims(c::TempCube{T,N},perm) where {T,N}=TempCubePerm{T,N}(c.axes,c.folder,c.block_size,perm,c.properties)
#Method for reading cubes that get transposed
#Per means fileOrder -> MemoryOrder
function _read(y::TempCubePerm,thedata::Tuple,r::CartesianIndices{CartesianIndex{N}}) where N
  data,mask=thedata
  perm=y.perm
  blocksize_trans = CartesianIndex(ntuple(i->y.block_size.I[perm[i]],N))
  iperm=getiperm(perm)
  unit=CartesianIndex{N}()
  rsmall=CartesianIndices(CIdiv(r.start-unit,blocksize_trans)+unit,CIdiv(r.stop-unit,blocksize_trans)+unit)
  for Ismall in rsmall
      bBig1=max(CItimes((Ismall-unit),blocksize_trans)+unit,r.start)
      bBig2=min(CItimes(Ismall,blocksize_trans),r.stop)
      iToread=CartesianIndices(bBig1-CItimes((Ismall-unit),blocksize_trans),bBig2-CItimes((Ismall-unit),blocksize_trans))
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


import ...ESDL.workdir

"""
    saveCube(c::AbstractCubeData, name::String)

Permanently saves a data cube to disk by either moving the folder out of the
tmp directory (for `TempCube`s) or by storing the data to disk (for `CubeMem`s)
"""
function saveCube(c::TempCube,name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && error("$(name) already exists, please pick another name")
  mv(c.folder,newfolder)
  c.folder=newfolder
  c.persist=true
end

"""
    loadCube(name::String)

Loads a cube that was previously saved with [`saveCube`](@ref). Returns a
`TempCube` object.
"""
function loadCube(name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) || error("$(name) does not exist")
  if any(i->basename(i)=="data.bin",readdir(newfolder))
    openmmapcube(newfolder)
  else
    openTempCube(newfolder)
  end
end



end #module
