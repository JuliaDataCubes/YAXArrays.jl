module DAT
export registerDATFunction, mapCube, getInAxes, getOutAxes, findAxis, reduceCube, getAxis,
      NaNMissing, ValueMissing, DataArrayMissing, MaskMissing, NoMissing, InputCube, OutputCube
importall ..Cubes
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
importall ..CABLABTools
importall ..Cubes.TempCubes
import ...CABLAB
import ...CABLAB.workdir
import DataFrames
import ..CubeAPI.CachedArrays.synccube
using Base.Dates
import DataArrays: DataArray, ismissing
import Missings: Missing, missing
import StatsBase.Weights
importall CABLAB.CubeAPI.Mask
global const debugDAT=false
macro debug_print(e)
  debugDAT && return(:(println($e)))
  :()
end
#Clear Temp Folder when loading
#myid()==1 && isdir(joinpath(workdir[1],"tmp")) && rm(joinpath(workdir[1],"tmp"),recursive=true)

"Supertype of missing value representations"
abstract type MissingRepr end
immutable NaNMissing <: MissingRepr end
immutable ValueMissing{T} <:MissingRepr
  v::T
end
immutable DataArrayMissing <: MissingRepr end
immutable MaskMissing <: MissingRepr end
immutable NoMissing <: MissingRepr end

toMissRepr(s::Symbol)=  s == :nan  ? NaNMissing() :
                        s == :mask ? MaskMissing() :
                        s == :data ? DataArrayMissing() :
                        s == :none ? NoMissing() :
                        error("Unknown missing value specifier: $s")
toMissRepr(n::Number) = ValueMissing(n)

function mask2miss(::NaNMissing, a, workAr)
  map!((m,v)->(m & 0x01)==0x01 ? convert(eltype(workAr),NaN) : v,workAr,a[2],a[1])

end
function mask2miss(::DataArrayMissing, a, workAr)
  map!(m->(m & 0x01)==0x01,workAr.na,a[2])
  copy!(workAr.data,a[1])
end
function mask2miss(::DataArrayMissing, a, workAr::DataFrames.DataFrame)
  for icol = 1:size(a[1],2)
    xnow,mnow = view(a[1],:,icol),view(a[2],:,icol)
    map!(m->(m & 0x01)==0x01,workAr[icol].na,mnow)
    copy!(workAr[icol].data,xnow)
  end
end
#mask2miss(::DataArrayMissing, a::Tuple{Number,UInt8}, workAr) = workAr[1]=(a[2] & 0x01)>0 ? missing : a[1]
mask2miss(::NoMissing,a,workAr) = copy!(workAr,a[1])
function mask2miss(::MaskMissing,a::Tuple,workAr::Tuple)
  copy!(workAr[1],a[1])
  copy!(workAr[2],a[2])
end
function mask2miss(o::ValueMissing,a,workAr)
  map!((m,v)->(m & 0x01)==0x01 ? oftype(v,o.v) : v,workAr,a[2],a[1])
  a[1]
end

function miss2mask!(::DataArrayMissing, target, source::DataArray)
  map!(j->j ? 0x01 : 0x00,target[2],source.na)
  copy!(target[1],source.data)
end
function miss2mask!(::DataArrayMissing, target, source::DataFrames.DataFrame)
  for icol = 1:size(target[1],2)
    xnow,mnow = view(target[1],:,icol),view(target[2],:,icol)
    map!(j->j ? 0x01 : 0x00,mnow,source[icol].na)
    copy!(xnow,source[icol].data)
  end
end
function miss2mask!(::DataArrayMissing, target, source::Union{Missing,Number})
  if ismissing(source)
    target[2][1] = 0x01
  else
    target[2][1] = 0x00
    target[1][1] = source
  end
end
function miss2mask!(::NaNMissing, target, source::Array)
  map!(j->isnan(j) ? 0x01 : 0x00,target[2],source)
  copy!(target[1],source)
end
function miss2mask!(::MaskMissing,target,source::Tuple{Array,Array})
  copy!(target[1],source[1])
  copy!(target[2],source[2])
end
function miss2mask!(::NoMissing,target,source)
  target[2][:] = 0x00
  copy!(target[1],source[1])
end

include("registration.jl")

"""
Internal representation of an input cube for DAT operations
"""
type InputCube
  cube::AbstractCubeData     #The input data cube
  desc::InDims           #The input description given by the user/registration
  axesSmall::Array{CubeAxis} #List of axes that were actually selected through the desciption
  bcinds::Vector{Int}        #Indices of loop axes that this cube does not contain, i.e. broadcasts
  cachesize::Vector{Int}     #Number of elements to keep in cache along each axis
  isMem::Bool                #is the cube in-memory
  handle::Any                #handle for the input
  workarray::Any
end

function InputCube(c::AbstractCubeData, desc::InDims)
  axesSmall = getAxis.(desc.axisdesc,c)
  isMem = isa(c,AbstractCubeMem)
  InputCube(c,desc,collect(axesSmall),CubeAxis[],Int[],isMem,nothing,nothing)
end
gethandle(c::InputCube)=c.handle
getcube(c::InputCube)=c.cube
import AxisArrays
function setworkarray(c::InputCube)
  wa = createworkarray(c.desc.miss,eltype(c.cube),ntuple(i->length(c.axesSmall[i]),length(c.axesSmall)))
  c.workarray = wrapWorkArray(c.desc.artype,wa,c.axesSmall)
end
createworkarray(m::NaNMissing,T,s)=Array{T}(s...)
createworkarray(m::ValueMissing,T,s)=Array{T}(s...)
createworkarray(m::DataArrayMissing,T,s)=DataArray(Array{T}(s...))
createworkarray(m::NoMissing,T,s)=Array{T}(s...)
createworkarray(m::MaskMissing,T,s)=(Array{T}(s...),Array{UInt8}(s...))




"""
Internal representation of an output cube for DAT operations
"""
type OutputCube
  cube::Nullable{AbstractCubeData} #The actual outcube cube, once it is generated
  desc::OutDims                 #The description of the output axes as given by users or registration
  axesSmall::Array{CubeAxis}       #The list of output axes determined through the description
  allAxes::Vector{CubeAxis}        #List of all the axes of the cube
  broadcastAxes::Vector{CubeAxis}         #List of axes that are broadcasted
  bcinds::Vector{Int}              #Index of the loop axes that are broadcasted for this output cube
  isMem::Bool                      #Shall the output cube be in memory
  handle::Any                      #Access handle for the cube
  workarray::Any
  folder::String                   #Folder to store the cube to
  outtype::DataType
end
gethandle(c::OutputCube)=c.handle
getcube(c::OutputCube)=get(c.cube)
getsmallax(c::Union{InputCube,OutputCube})=c.axesSmall
getAxis(desc,c::OutputCube)=getAxis(desc,get(c.cube))
getAxis(desc,c::InputCube)=getAxis(desc,c.cube)
function setworkarray(c::OutputCube)
  wa = createworkarray(c.desc.miss,eltype(get(c.cube)),ntuple(i->length(c.axesSmall[i]),length(c.axesSmall)))
  c.workarray = wrapWorkArray(c.desc.artype,wa,c.axesSmall)
end

function OutputCube(outfolder,desc::OutDims,inAxes::Vector{CubeAxis},incubes,pargs)
  axesSmall = map(i->getOutAxis(i,inAxes,incubes,pargs),desc.axisdesc)
  broadcastAxes = map(i->getOutAxis(i,inAxes,incubes,pargs),desc.bcaxisdesc)
  outtype = getOuttype(desc.outtype,incubes)
  OutputCube(Nullable{AbstractCubeData}(),desc,collect(CubeAxis,axesSmall),CubeAxis[],collect(CubeAxis,broadcastAxes),Int[],false,nothing,nothing,outfolder,outtype)
end

"""
Collects axes from all input cubes into a single vector
"""
function getAllInaxes(cdata)
  o = CubeAxis[]
  foreach(cdata) do c
    foreach(axes(c)) do ax
      namecur = axname(ax)
      samename = findfirst(i->axname(i)==namecur,o)
      if samename == 0 #There is no axis of the same name yet
        push!(o,ax)
      else
        o[samename]==ax || error("The axis $namecur appears multiple times, but contains different values. $(o[samename]) $ax")
      end
    end
  end
  return o
end

"""
Configuration object of a DAT process. This holds all necessary information to perform the calculations
It contains the following fields:

- `incubes::Vector{AbstractCubeData}` The input data cubes
- `outcube::AbstractCubeData` The output data cube
- `indims::Vector{Tuple}` Tuples of input axis types
- `outdims::Tuple` Tuple of output axis types
- `axlists::Vector{Vector{CubeAxis}}` Axes of the input data cubes
- `inAxes::Vector{Vector{CubeAxis}}`
- outAxes::Vector{CubeAxis}
- LoopAxes::Vector{CubeAxis}
- axlistOut::Vector{CubeAxis}
- ispar::Bool
- isMem::Vector{Bool}
- inCubesH
- outCubeH

"""
type DATConfig{NIN,NOUT}
  incubes       :: NTuple{NIN,InputCube}
  outcubes      :: NTuple{NOUT,OutputCube}
  allInAxes     :: Vector
  LoopAxes      :: Vector
  ispar         :: Bool
  loopCacheSize :: Vector{Int}
  max_cache
  fu
  no_ocean      :: Int
  inplace      :: Bool
  addargs
  kwargs
end
function DATConfig(cdata,reginfo,max_cache,fu,outfolder,ispar,addargs,kwargs)

  length(cdata)==length(reginfo.inCubes) || error("Number of input cubes ($(length(cdata))) differs from registration ($(length(reginfo.inCubes)))")

  allInAxes = getAllInaxes(cdata)
  incubes  = totuple([InputCube(o[1],o[2]) for o in zip(cdata,reginfo.inCubes)])
  outcubes = totuple(map(1:length(reginfo.outCubes),reginfo.outCubes) do i,desc
     OutputCube( string(outfolder,"_",i),desc,allInAxes,cdata,addargs )
    end)


  DATConfig(
    incubes,
    outcubes,
    allInAxes,
    CubeAxis[],                                 # LoopAxes
    ispar,
    Int[],
    max_cache,                                  # max_cache
    fu,                                         # fu                                      # loopCacheSize
    reginfo.no_ocean,                                   # no_ocean
    reginfo.inplace,                                    # inplace
    addargs,                                    # addargs
    kwargs
  )

end

"""
Object to pass to InnerLoop, this condenses the most important information about the calculation into a type so that
specific code can be generated by the @generated function
"""
immutable InnerObj{T1,T2,T3,OC,R,UPDOUT} end
function InnerObj(dc::DATConfig)
  T1=totuple(length.(getsmallax.(dc.incubes)))
  T2=totuple(length.(getsmallax.(dc.outcubes)))
  inbroad = collect(Any,map(i->totuple(i.bcinds),dc.incubes))
  outbroad= collect(Any,map(i->totuple(i.bcinds),dc.outcubes))
  upd = map(i->i.desc.update,dc.outcubes)
  UPDOUT = totuple(find(upd))
  T3=totuple([inbroad;outbroad])
  OC=dc.no_ocean
  R=dc.inplace
  InnerObj{T1,T2,T3,OC,R,UPDOUT}()
end


getOuttype(outtype::Int,cdata)=eltype(cdata[outtype])
function getOuttype(outtype::DataType,cdata)
  isleaftype(outtype) ? outtype : eltype(cdata[1])
end

mapCube(fu::Function,cdata::AbstractCubeData,addargs...;kwargs...)=mapCube(fu,(cdata,),addargs...;kwargs...)


"""
    reduceCube(f::Function, cube, dim::Type{T<:CubeAxis};kwargs...)

Apply a reduction function `f` on slices of the cube `cube`. The dimension(s) are specified through `dim`, which is
either an Axis type or a tuple of axis types. Keyword arguments are passed to `mapCube` or, if unknown passed again to `f`.
It is assumed that `f` takes an array input and returns a single value.
"""
reduceCube{T<:CubeAxis}(f::Function,c::CABLAB.Cubes.AbstractCubeData,dim::Type{T},addargs...;kwargs...)=reduceCube(f,c,(dim,),addargs...;kwargs...)
function reduceCube(f::Function,c::CABLAB.Cubes.AbstractCubeData,dim::Tuple,addargs...;kwargs...)
  isa(dim[1],Tuple) || (dim=(dim,))
  if in(LatAxis,dim)
    axlist=axes(c)
    inAxes=map(i->getAxis(i,axlist),dim)
    latAxis=getAxis(LatAxis,axlist)
    sfull=map(length,inAxes)
    ssmall=map(i->isa(i,LatAxis) ? length(i) : 1,inAxes)
    wone=reshape(cosd.(latAxis.values),ssmall)
    ww=zeros(sfull).+wone
    wv=Weights(reshape(ww,length(ww)))
    g = length(dim)>1 ? (x,w;kwargs...)->f(DataArray(reshape(x.data,length(x)),reshape(x.na,length(x))),w;kwargs...) : f
    return mapCube(g,c,wv,addargs...;incubes=map(i->InDims((get_descriptor.(i))...),dim),outcubes=(OutDims(),),inplace=false,kwargs...)
  else
    return mapCube(f,c,addargs...;incubes=map(i->InDims((get_descriptor.(i))...),dim),outcubes=(OutDims(),),inplace=false,kwargs...)
  end
end


"""
    mapCube(fun, cube, addargs...;kwargs)

Map a given function `fun` over slices of the data cube `cube`.

### Keyword arguments

* `max_cache=1e7` maximum size of blocks that are read into memory, defaults to approx 10Mb
* `outtype::DataType` output data type of the operation
* `indims::Tuple{Tuple{Vararg{CubeAxis}}}` List of input axis types for each input data cube
* `outdims::Tuple` List of output axes, can be either an axis type that has a default constructor or an instance of a `CubeAxis`
* `inmissing::Tuple` How to treat missing values in input data for each input cube. Possible values are `:data` `:mask` `:nan` or a value that is inserted for missing data, defaults to `:mask`
* `outmissing` How are missing values written to the output array, possible values are `:data`, `:mask`, `:nan`, defaults to `:mask`
* `no_ocean` should values containing ocean data be omitted, an integer specifying the cube whose input mask is used to determine land-sea points.
* `inplace` does the function write to an output array inplace or return a single value> defaults to `true`
* `ispar` boolean to determine if parallelisation should be applied, defaults to `true` if workers are available.
* `kwargs` additional keyword arguments passed to the inner function

The first argument is always the function to be applied, the second is the input cube or
a tuple input cubes if needed. If the function to be applied is registered (either as part of CABLAB or through [registerDATFunction](@ref)),
all of the keyword arguments have reasonable defaults and don't need to be supplied. Some of the function still need additional arguments or keyword
arguments as is stated in the documentation.

If you want to call mapCube directly on an unregistered function, please have a look at [Applying custom functions](@ref) to get an idea about the usage of the
input and output dimensions etc.
"""
function mapCube(fu::Function,
    cdata::Tuple,addargs...;
    max_cache=1e7,
    incubes=nothing,
    outcubes=nothing,
    no_ocean=nothing,
    inplace=nothing,
    outfolder=joinpath(workdir[1],string(tempname()[2:end],fu)),
    ispar=nprocs()>1,
    debug=false,
    kwargs...)
  @debug_print "Check if function is registered"
  if haskey(regDict,fu)
    reginfo = regDict[fu]
    overwrite_settings!(reginfo,incubes,outcubes,no_ocean,inplace)
  else
    reginfo = regFromScratch(incubes,outcubes,no_ocean,inplace,addargs)
  end
  @debug_print "Generating DATConfig"
  dc=DATConfig(cdata,reginfo,
    max_cache,fu,outfolder,ispar,addargs,kwargs)
  analyseaddargs(reginfo,dc)
  @debug_print "Reordering Cubes"
  reOrderInCubes(dc)
  @debug_print "Analysing Axes"
  analyzeAxes(dc)
  @debug_print "Calculating Cache Sizes"
  getCacheSizes(dc)
  @debug_print "Generating Output Cube"
  generateOutCubes(dc)
  @debug_print "Generating cube handles"
  getCubeHandles(dc)
  generateworkarrays(dc)
  @debug_print "Running main Loop"
  debug && return(dc)
  runLoop(dc)
  @debug_print "Finalizing Output Cube"

  if length(dc.outcubes)==1
    return dc.outcubes[1].desc.finalizeOut(get(dc.outcubes[1].cube))
  else
    return totuple(map(i->i.desc.finalizeOut(get(i.cube)),dc.outcubes))
  end

end

function analyseaddargs(sfu::DATFunction,dc)
    dc.addargs=isa(sfu.args,Function) ? sfu.args(dc.incubes,dc.addargs) : dc.addargs
end
analyseaddargs(sfu::Function,dc)=nothing

mustReorder(cdata,inAxes)=!all(axes(cdata)[1:length(inAxes)].==inAxes)

function reOrderInCubes(dc::DATConfig)
  ics = dc.incubes
  for (i,ic) in enumerate(ics)
    ax = ic.axesSmall
    if mustReorder(ic.cube,ax)
      perm=getFrontPerm(ic.cube,ax)
      ic.cube=permutedims(ic.cube,perm)
    end
  end
end

function synccube(x::Tuple{Array,Array})
  Mmap.sync!(x[1])
  Mmap.sync!(x[2])
end

function runLoop(dc::DATConfig)
  if dc.ispar
    #TODO CHeck this for multiple output cubes, how to parallelize
    #I thnk this should work, but not 100% sure yet
    allRanges=distributeLoopRanges(totuple(dc.loopCacheSize),map(length,dc.LoopAxes))
    pmap(r->CABLAB.DAT.innerLoop( Main.PMDATMODULE.dc.fu,
                                  CABLAB.CABLABTools.totuple(CABLAB.DAT.gethandle.(Main.PMDATMODULE.dc.incubes)),
                                  CABLAB.CABLABTools.totuple(CABLAB.DAT.gethandle.(Main.PMDATMODULE.dc.outcubes)),
                                  CABLAB.DAT.InnerObj(Main.PMDATMODULE.dc),
                                  r,
                                  totuple(map(i->i.workarray,Main.PMDATMODULE.dc.incubes)),
                                  totuple(map(i->i.workarray,Main.PMDATMODULE.dc.outcubes)),
                                  totuple(map(i->i.desc.miss,Main.PMDATMODULE.dc.incubes)),
                                  totuple(map(i->i.desc.miss,Main.PMDATMODULE.dc.outcubes)),
                                  Main.PMDATMODULE.dc.addargs,
                                  Main.PMDATMODULE.dc.kwargs)
          ,allRanges)
  else
    innerLoop(dc.fu,
              totuple(gethandle.(dc.incubes)),
              totuple(gethandle.(dc.outcubes)),
              InnerObj(dc),
              totuple(length.(dc.LoopAxes)),
              totuple(map(i->i.workarray,dc.incubes)),
              totuple(map(i->i.workarray,dc.outcubes)),
              totuple(map(i->i.desc.miss,dc.incubes)),
              totuple(map(i->i.desc.miss,dc.outcubes)),
              dc.addargs,
              dc.kwargs)
  end
  dc.outcubes
end

function getRetCubeType(oc,ispar,max_cache)
  eltype=typeof(oc.desc.genOut(oc.outtype))
  outsize=sizeof(eltype)*(length(oc.allAxes)>0 ? prod(map(length,oc.allAxes)) : 1)
  if string(oc.desc.retCubeType)=="auto"
    if ispar || outsize>max_cache
      cubetype = MmapCube
    else
      cubetype = CubeMem
    end
  else
    cubetype = oc.desc.retCubeType
  end
  eltype,cubetype
end

function generateOutCube{T<:TempCube}(::Type{T},eltype,oc::OutputCube,loopCacheSize)
  oc.cube=TempCube(oc.allAxes,CartesianIndex(totuple([map(length,oc.axesSmall);loopCacheSize])),folder=oc.folder,T=eltype,persist=false)
end
function generateOutCube{T<:MmapCube}(::Type{T},eltype,oc::OutputCube,loopCacheSize)
  oc.cube=MmapCube(oc.allAxes,folder=oc.folder,T=eltype,persist=false)
end
function generateOutCube{T<:CubeMem}(::Type{T},eltype,oc::OutputCube,loopCacheSize)
  newsize=map(length,oc.allAxes)
  outar=Array{eltype}(newsize...)
  genFun=oc.desc.genOut
  map!(_->genFun(eltype),outar,outar)
  oc.cube = Cubes.CubeMem(oc.allAxes,outar,zeros(UInt8,newsize...))
end

generateOutCubes(dc::DATConfig)=foreach(c->generateOutCube(c,dc.ispar,dc.max_cache,dc.loopCacheSize),dc.outcubes)
function generateOutCube(oc::OutputCube,ispar::Bool,max_cache,loopCacheSize)
  eltype,cubetype = getRetCubeType(oc,ispar,max_cache)
  generateOutCube(cubetype,eltype,oc,loopCacheSize)
end

sethandle(c::InputCube) = (c.handle = gethandle(c.cube,CartesianIndex(totuple(c.cachesize))))
sethandle(c::OutputCube) = (c.handle = (gethandle(get(c.cube))))


dcg=nothing
function getCubeHandles(dc::DATConfig)
  if dc.ispar
    freshworkermodule()
    global dcg=dc
      passobj(1, workers(), [:dcg],from_mod=CABLAB.DAT,to_mod=Main.PMDATMODULE)
    @everywhereelsem begin
      dc=Main.PMDATMODULE.dcg
      foreach(CABLAB.DAT.sethandle,dc.outcubes)
      foreach(CABLAB.DAT.sethandle,dc.incubes)
    end
  else
    foreach(sethandle,dc.outcubes)
    foreach(sethandle,dc.incubes)
  end
end

function init_DATworkers()
  freshworkermodule()
end

function analyzeAxes{NIN,NOUT}(dc::DATConfig{NIN,NOUT})
  #First check if one of the axes is a concrete type
  for cube in dc.incubes
    for a in axes(cube.cube)
      in(a,cube.axesSmall) || in(a,dc.LoopAxes) || push!(dc.LoopAxes,a)
    end
  end
  length(dc.LoopAxes)==length(unique(map(typeof,dc.LoopAxes))) || error("Make sure that cube axes of different cubes match")
  for cube=dc.incubes
    myAxes = axes(cube.cube)
    for (il,loopax) in enumerate(dc.LoopAxes)
      !in(typeof(loopax),map(typeof,myAxes)) && push!(cube.bcinds,il)
    end
  end
  #Add output broadcast axes
  for outcube=dc.outcubes
    LoopAxesAdd=CubeAxis[]
    for (il,loopax) in enumerate(dc.LoopAxes)
      if loopax in outcube.broadcastAxes
        push!(outcube.bcinds,il)
      else
        push!(LoopAxesAdd,loopax)
      end
    end
    outcube.allAxes=CubeAxis[outcube.axesSmall;LoopAxesAdd]
  end
  return dc
end

function getCacheSizes(dc::DATConfig)

  if all(i->i.isMem,dc.incubes)
    dc.loopCacheSize=Int[length(x) for x in dc.LoopAxes]
    return dc
  end
  inAxlengths      = map(cube->Int.(length.(cube.axesSmall)),dc.incubes)
  inblocksizes     = map((x,T)->prod(x)*sizeof(eltype(T.cube)),inAxlengths,dc.incubes)
  inblocksize,imax = findmax(inblocksizes)
  outblocksizes    = map(C->length(C.axesSmall)>0 ? sizeof(C.outtype)*prod(map(length,C.axesSmall)) : 1,dc.outcubes)
  outblocksize     = length(outblocksizes) > 0 ? findmax(outblocksizes)[1] : 1
  loopCacheSize    = getLoopCacheSize(max(inblocksize,outblocksize),dc.LoopAxes,dc.max_cache)
  for cube in dc.incubes
    if !cube.isMem
      cube.cachesize = map(length,cube.axesSmall)
      for (cs,loopAx) in zip(loopCacheSize,dc.LoopAxes)
        in(typeof(loopAx),map(typeof,axes(cube.cube))) && push!(cube.cachesize,cs)
      end
    end
  end
  dc.loopCacheSize=loopCacheSize
  return dc
end

"Calculate optimal Cache size to DAT operation"
function getLoopCacheSize(preblocksize,LoopAxes,max_cache)
  totcachesize=max_cache

  incfac=totcachesize/preblocksize
  incfac<1 && error("The requested slices do not fit into the specified cache. Please consider increasing max_cache")
  loopCacheSize = ones(Int,length(LoopAxes))
  for iLoopAx=1:length(LoopAxes)
    s=length(LoopAxes[iLoopAx])
    if s<incfac
      loopCacheSize[iLoopAx]=s
      incfac=incfac/s
      continue
    else
      ii=floor(Int,incfac)
      while ii>1 && rem(s,ii)!=0
        ii=ii-1
      end
      loopCacheSize[iLoopAx]=ii
      break
    end
  end
  return loopCacheSize
end

using Base.Cartesian
@generated function distributeLoopRanges{N}(block_size::NTuple{N,Int},loopR::Vector)
    quote
        @assert length(loopR)==N
        nsplit=helpComprehension_nsplit(block_size, loopR)
        baseR=helpComprehension_baseR(block_size)
        a=Array{NTuple{$N,UnitRange{Int}}}(nsplit...)
        @nloops $N i a begin
            rr=@ntuple $N d->baseR[d]+(i_d-1)*block_size[d]
            @nref($N,a,i)=rr
        end
        a=reshape(a,length(a))
    end
end

function generateworkarrays(dc::DATConfig)
  if dc.ispar
    @everywhereelsem foreach(CABLAB.DAT.setworkarray,PMDATMODULE.dc.incubes)
    @everywhereelsem foreach(CABLAB.DAT.setworkarray,PMDATMODULE.dc.outcubes)
  else
    foreach(setworkarray,dc.incubes)
    foreach(setworkarray,dc.outcubes)
  end
end

#Comprehensions are not allowed in generated functions so they have to moved to normal function
# see https://github.com/JuliaLang/julia/issues/21094
function helpComprehension_nsplit{N}(block_size::NTuple{N,Int},loopR::Vector)
    nsplit=Int[div(l,b) for (l,b) in zip(loopR,block_size)]
    return nsplit
end
function helpComprehension_baseR{N}(block_size::NTuple{N,Int})
    baseR=UnitRange{Int}[1:b for b in block_size]
    return baseR
end


using Base.Cartesian
@generated function innerLoop{T1,T2,T3,T4,OC,R,NIN,NOUT,UPDOUT}(f,xin::NTuple{NIN,Union{AbstractCubeData,CachedArray,Tuple{Array,Array}}},xout::NTuple{NOUT,Union{AbstractCubeData,CachedArray,Tuple{Array,Array}}},::InnerObj{T1,T2,T4,OC,R,UPDOUT},loopRanges::T3,
  inwork,outwork,inmissing,outmissing,addargs,kwargs)

  NinCol      = T1
  NoutCol     = T2
  broadcastvars = T4
  Nloopvars   = length(T3.parameters)
  loopRangesE = Expr(:block)
  unrollEx = Expr(:block)
  inworksyms = map(i->Symbol(string("inwork_",i)),1:NIN)
  outworksyms= map(i->Symbol(string("outwork_",i)),1:NOUT)
  [push!(unrollEx.args,:($(inworksyms[i]) = inwork[$i])) for i=1:NIN]
  [push!(unrollEx.args,:($(outworksyms[i]) = outwork[$i])) for i=1:NOUT]
  subIn = map(1:NIN) do i
    ex = Expr(:call, :getSubRange2, :(inmissing[$i]), inworksyms[i],  :(xin[$i]),  fill(:(:),NinCol[i])...)
    foreach(j->in(j,broadcastvars[i]) || push!(ex.args,Symbol("i_$j")),1:Nloopvars)
    ex
  end
  subOut = Expr[]
  syncex = quote end
  #Decide how to treat the output, create a view or copy in the end...
  for i=1:NOUT
    if !in(i,UPDOUT)
      ex = Expr(:call, :setSubRange2, :(outmissing[$i]), outworksyms[i], :(xout[$i]), fill(:(:),NoutCol[i])...)
      foreach(j->in(j,broadcastvars[NIN+i]) || push!(ex.args,Symbol("i_$j")),1:Nloopvars)
      push!(subOut, ex)
    else
      rhs = Expr(:call, :getSubRange, :(xout[$i]),  fill(:(:),NoutCol[i])...)
      foreach(j->in(j,broadcastvars[NIN+i]) || push!(rhs.args,Symbol("i_$i")),1:Nloopvars)
      push!(rhs.args,Expr(:kw,:write,true))
      push!(subIn,:($(outworksyms[i]) = $(rhs)[1]))
    end
    push!(syncex.args,:(synccube(xout[$i])))
  end
  for i=1:Nloopvars
    isym=Symbol("i_$(i)")
    if T3.parameters[i]==UnitRange{Int}
      unshift!(loopRangesE.args,:($isym=loopRanges[$i]))
    elseif T3.parameters[i]==Int
      unshift!(loopRangesE.args,:($isym=1:loopRanges[$i]))
    else
      error("Wrong Range argument")
    end
  end
  loopBody=quote end
  callargs=Any[:f,Expr(:parameters,Expr(:...,:kwargs))]
  R && foreach(j->push!(callargs,outworksyms[j]),1:NOUT)
  OC>0 && (subIn[OC]=:(oc = $(subIn[OC])))
  append!(loopBody.args,subIn)
  append!(callargs,inworksyms)
  if OC>0
    allocs = map(1:NOUT) do i
      exoc = Expr(:call, :setSubRangeOC, :(xout[$i]), fill(:(:),NoutCol[i])...)
      foreach(j->in(j,broadcastvars[NIN+i]) || push!(exoc.args,Symbol("i_$j")),1:Nloopvars)
      exoc
    end
    ocex=quote
      if oc
        $(Expr(:block,allocs...))
        continue
      end
    end
    push!(loopBody.args,ocex)
  end
  push!(callargs,Expr(:...,:addargs))
  if R
    push!(loopBody.args,Expr(:call,callargs...))
  else
    lhs = Expr(:tuple,[:($(outworksyms[j])[:]) for j=1:NOUT]...)
    rhs = Expr(:call,callargs...)
    push!(loopBody.args,:($lhs=$rhs))
  end
  append!(loopBody.args,subOut)
  loopEx = length(loopRangesE.args)==0 ? loopBody : Expr(:for,loopRangesE,loopBody)
  loopEx = quote
    $unrollEx
    $loopEx

  end
  if debugDAT
    b=IOBuffer()
    show(b,loopEx)
    s=String(take!(b))
    loopEx=quote
      println($s)
      $loopEx
    end
  end
  loopEx
end

function getSubRange2(missrep,work,xin,cols...)
  xview = getSubRange(xin,cols...)
  mask2miss(missrep,xview,work)
  return xview[2][1]==OCEAN
end

function setSubRange2(missrep,work,xout,cols...)
  xview = getSubRange(xout,cols...,write=true)
  miss2mask!(missrep,xview,work)
end

function setSubRangeOC(xout,cols...)
  xview = getSubRange(xout,cols...,write=true)
  xview[2][:] = OCEAN
end

getSubRange(x::Tuple{Array,Array},cols...;write=false)=(view(x[1],cols...),view(x[2],cols...))

"Calculate an axis permutation that brings the wanted dimensions to the front"
function getFrontPerm{T}(dc::AbstractCubeData{T},dims)
  ax=axes(dc)
  N=length(ax)
  perm=Int[i for i=1:length(ax)];
  iold=Int[]
  for i=1:length(dims) push!(iold,findAxis(dims[i],ax)) end
  iold2=sort(iold,rev=true)
  for i=1:length(iold) splice!(perm,iold2[i]) end
  perm=Int[iold;perm]
  return ntuple(i->perm[i],N)
end

end
