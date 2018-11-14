module DAT
export mapCube, getInAxes, getOutAxes, findAxis, reduceCube, getAxis, InputCube, OutputCube
using ..Cubes
using ..CubeAPI
using ..ESDLTools
using Distributed
import ..Cubes: getAxis, getOutAxis, getAxis, cubechunks, iscompressed, chunkoffset, _write
import ...ESDL
import ...ESDL.workdir
import DataFrames
import Distributed: nprocs
import DataFrames: DataFrame
import ProgressMeter: Progress, next!
using Dates
import StatsBase.Weights
using ESDL.CubeAPI.Mask
global const debugDAT=false
macro debug_print(e)
  debugDAT && return(:(println($e)))
  :()
end

using Requires

const hasparprogress=[false]
const progresscolor=[:cyan]
function __init__()
  @require IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a" begin progresscolor[1] = :blue end
end

function mask2miss(a::MaskArray,workAr::MaskArray)
  copyto!(workAr.data,a.data)
  copyto!(workAr.mask,a.mask)
end
function mask2miss(a::MaskArray,workAr::DataFrame)
  for ivar in 1:size(a,2), iobs in 1:size(a,1)
    if iszero(a.mask[iobs,ivar] & 0x01)
      workAr[iobs,ivar]=a.data[iobs,ivar]
    else
      workAr[iobs,ivar]=missing
    end
  end
end
function miss2mask!(target,source::MaskArray)
  copyto!(target.data,source.data)
  copyto!(target.mask,source.mask)
end
function miss2mask!(target,source::DataFrame)
  copyto!(target.data,source)
  map!(i->ismissing(i) ? 0x01 : 0x00, target.mask,source)
end

include("registration.jl")

"""
Internal representation of an input cube for DAT operations
"""
mutable struct InputCube{N}
  cube::AbstractCubeData{<:Any,N}   #The input data cube
  desc::InDims               #The input description given by the user/registration
  axesSmall::Array{CubeAxis} #List of axes that were actually selected through the desciption
  loopinds::Vector{Int}        #Indices of loop axes that this cube does not contain, i.e. broadcasts
  cachesize::Vector{Int}     #Number of elements to keep in cache along each axis
  isMem::Bool                #is the cube in-memory
  handle::Any                #allocated cache
  workarray::Any
end

function InputCube(c::AbstractCubeData, desc::InDims)
  axesSmall = getAxis.(desc.axisdesc,Ref(c))
  isMem = isa(c,AbstractCubeMem)
  InputCube(c,desc,collect(CubeAxis,axesSmall),Int[],Int[],isMem,nothing,nothing)
end
getcube(c::InputCube)=c.cube
import AxisArrays
function setworkarray(c::InputCube)
  wa = createworkarray(eltype(c.cube),ntuple(i->length(c.axesSmall[i]),length(c.axesSmall)))
  c.workarray = wrapWorkArray(c.desc.artype,wa,c.axesSmall)
end
createworkarray(T,s)=MaskArray(Array{T}(undef,s...),Array{UInt8}(undef,s...))




"""
Internal representation of an output cube for DAT operations
"""
mutable struct OutputCube
  cube::Union{AbstractCubeData,Nothing} #The actual outcube cube, once it is generated
  desc::OutDims                 #The description of the output axes as given by users or registration
  axesSmall::Array{CubeAxis}       #The list of output axes determined through the description
  allAxes::Vector{CubeAxis}        #List of all the axes of the cube
  broadcastAxes::Vector{CubeAxis}         #List of axes that are broadcasted
  loopinds::Vector{Int}              #Index of the loop axes that are broadcasted for this output cube
  isMem::Bool                      #Shall the output cube be in memory
  workarray::Any
  handle::Any                       #Cache to write the output to
  folder::String                   #Folder to store the cube to
  outtype::DataType
end
getcube(c::OutputCube)      = c.cube
getsmallax(c::Union{InputCube,OutputCube})=c.axesSmall
getAxis(desc,c::OutputCube) = getAxis(desc,c.cube)
getAxis(desc,c::InputCube)  = getAxis(desc,c.cube)
function setworkarray(c::OutputCube)
  wa = createworkarray(eltype(c.cube),ntuple(i->length(c.axesSmall[i]),length(c.axesSmall)))
  c.workarray = wrapWorkArray(c.desc.artype,wa,c.axesSmall)
end

getOutAxis(desc::Tuple,inAxes,incubes,pargs,f)=map(i->getOutAxis(i,inAxes,incubes,pargs,f),desc)
function OutputCube(outfolder,desc::OutDims,inAxes::Vector{CubeAxis},incubes,pargs,f)
  axesSmall     = getOutAxis(desc.axisdesc,inAxes,incubes,pargs,f)
  broadcastAxes = getOutAxis(desc.bcaxisdesc,inAxes,incubes,pargs,f)
  outtype       = getOuttype(desc.outtype,incubes)
  OutputCube(nothing,desc,collect(CubeAxis,axesSmall),CubeAxis[],collect(CubeAxis,broadcastAxes),Int[],false,nothing,nothing,outfolder,outtype)
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
mutable struct DATConfig{NIN,NOUT}
  incubes       :: NTuple{NIN,InputCube}
  outcubes      :: NTuple{NOUT,OutputCube}
  allInAxes     :: Vector
  LoopAxes      :: Vector
  ispar         :: Bool
  loopCacheSize :: Vector{Int}
  max_cache
  fu
  inplace      :: Bool
  include_loopvars:: Bool
  addargs
  kwargs
end
function DATConfig(cdata,indims,outdims,inplace,max_cache,fu,outfolder,ispar,include_loopvars,addargs,kwargs)

  isa(indims,InDims) && (indims=(indims,))
  isa(outdims,OutDims) && (outdims=(outdims,))
  length(cdata)==length(indims) || error("Number of input cubes ($(length(cdata))) differs from registration ($(length(indims)))")

  incubes  = totuple([InputCube(o[1],o[2]) for o in zip(cdata,indims)])
  allInAxes = vcat([ic.axesSmall for ic in incubes]...)
  outcubes = totuple(map(1:length(outdims),outdims) do i,desc
     OutputCube(string(outfolder,"_",i),desc,allInAxes,cdata,addargs,fu)
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
    inplace,                                    # inplace
    include_loopvars,
    addargs,                                    # addargs
    kwargs
  )

end

"""
Object to pass to InnerLoop, this condenses the most important information about the calculation into a type so that
specific code can be generated by the @generated function
"""
struct InnerObj{T1,T2,T3,R,UPDOUT,LR} end
function InnerObj(dc::DATConfig)
  T1=totuple(length.(getsmallax.(dc.incubes)))
  T2=totuple(length.(getsmallax.(dc.outcubes)))
  inbroad = collect(Any,map(i->totuple(i.loopinds),dc.incubes))
  outbroad= collect(Any,map(i->totuple(i.loopinds),dc.outcubes))
  upd = map(i->i.desc.update,dc.outcubes)
  UPDOUT = totuple(findall(upd))
  T3=totuple([inbroad;outbroad])
  R=dc.inplace
  LR=dc.include_loopvars
  InnerObj{T1,T2,T3,R,UPDOUT,LR}()
end


getOuttype(outtype::Int,cdata)=eltype(cdata[outtype])
function getOuttype(outtype::DataType,cdata)
  isconcretetype(outtype) ? outtype : eltype(cdata[1])
end

mapCube(fu::Function,cdata::AbstractCubeData,addargs...;kwargs...)=mapCube(fu,(cdata,),addargs...;kwargs...)

import Base.mapslices
function mapslices(f,d::AbstractCubeData,dims,addargs...;kwargs...)
    isa(dims,String) && (dims=(dims,))
    mapCube(f,d,addargs...;indims = InDims(dims...),outdims = OutDims(ByInference()),inplace=false,kwargs...)
end



"""
    mapCube(fun, cube, addargs...;kwargs)

Map a given function `fun` over slices of the data cube `cube`.

### Keyword arguments

* `max_cache=1e7` maximum size of blocks that are read into memory, defaults to approx 10Mb
* `outtype::DataType` output data type of the operation
* `indims::InDims List of input cube descriptors of type [`InDims`](@ref) for each input data cube
* `outdims::OutDims` List of output cube descriptors of type [`OutDims`](@ref) for each output cube
* `inplace` does the function write to an output array inplace or return a single value> defaults to `true`
* `ispar` boolean to determine if parallelisation should be applied, defaults to `true` if workers are available.
* `outfolder` a folder where the output cube is stroed, defaults to the result of `ESDLdir()`
* `kwargs` additional keyword arguments passed to the inner function

The first argument is always the function to be applied, the second is the input cube or
a tuple input cubes if needed.


"""
function mapCube(fu::Function,
    cdata::Tuple,addargs...;
    max_cache=1e7,
    indims=InDims(),
    outdims=OutDims(),
    inplace=true,
    outfolder=joinpath(workdir[1],string(tempname()[2:end],fu)),
    ispar=nprocs()>1,
    debug=false,
    include_loopvars=false,
    kwargs...)
  @debug_print "Check if function is registered"
  @debug_print "Generating DATConfig"
  dc=DATConfig(cdata,indims,outdims,inplace,
    max_cache,fu,outfolder,ispar,include_loopvars,addargs,kwargs)
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
  @debug_print "Generating work arrays"
  generateworkarrays(dc)
  @debug_print "Running main Loop"
  debug && return(dc)
  runLoop(dc)
  @debug_print "Finalizing Output Cube"

  if length(dc.outcubes)==1
    return dc.outcubes[1].desc.finalizeOut(dc.outcubes[1].cube)
  else
    return totuple(map(i->i.desc.finalizeOut(i.cube),dc.outcubes))
  end

end

mustReorder(cdata,inAxes)=!all(caxes(cdata)[1:length(inAxes)].==inAxes)

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
using Mmap
function synccube(x::Tuple{Array,Array})
  Mmap.sync!(x[1])
  Mmap.sync!(x[2])
end

function getchunkoffsets(dc::DATConfig)
  co = zeros(Int,length(dc.LoopAxes))
  for ic in dc.incubes
    #@show chunkoffset
    for (ax,cocur) in zip(caxes(ic.cube),chunkoffset(ic.cube))
      ii = findAxis(ax,dc.LoopAxes)
      if !isa(ii,Nothing) && iszero(co[ii]) && cocur>0
        co[ii]=cocur
      end
    end
  end
  totuple(co)
end

updatears(dc,clist,r,f) = foreach(clist) do ic
  indscol = ntuple(i->1:size(ic.cube,i),length(ic.axesSmall))
  indsr   = ntuple(i->r[ic.loopinds[i]],length(ic.loopinds))
  indsall = CartesianIndices((indscol...,indsr...))
  if size(ic.handle) != size(indsall)
    hinds = map(i->1:length(i),indsall.indices)
    f(ic.cube,view(ic.handle,hinds...),indsall)
  else
    f(ic.cube,ic.handle,indsall)
  end
  nothing
end
updateinars(dc,r)=updatears(dc,dc.incubes,r,_read)
writeoutars(dc,r)=updatears(dc,dc.outcubes,r,_write)

function runLoop(dc::DATConfig)
  allRanges=distributeLoopRanges(totuple(dc.loopCacheSize),totuple(map(length,dc.LoopAxes)),getchunkoffsets(dc))
  #@show collect(allRanges)
  if dc.ispar
    pmapfun = isdefined(:Main,:ProgressMeter) ? progress_pmap : pmap
    pmapfun(runLooppar,allRanges)
  else
    runLoop(dc,allRanges,isdefined(:Main,:ProgressMeter))
  end
  dc.outcubes
end

function runLooppar(allRanges)
  dc = Main.PMDATMODULE.dc
  runLoop(dc,(allRanges,),false)
end

function getallargs(dc::DATConfig)
  inars = map(ic->ic.handle,dc.incubes)
  outars = map(ic->ic.handle,dc.outcubes)
  filters = map(ic->ic.desc.procfilter,dc.incubes)
  inob = InnerObj(dc)
  inworkar = totuple(map(i->i.workarray,dc.incubes))
  outworkar = totuple(map(i->i.workarray,dc.outcubes))
  loopax = totuple(dc.LoopAxes)
  adda = dc.addargs
  kwa = dc.kwargs
  (inars,outars,filters,inob,inworkar,outworkar,
  loopax,adda,kwa)
end

function runLoop(dc::DATConfig, allRanges, showprog)
  allargs = getallargs(dc)
  runLoopArgs(dc,allargs,allRanges,showprog)
end

@noinline function runLoopArgs(dc,args,allRanges,doprogress)
  doprogress && (pm = Progress(length(allRanges)))
  for r in allRanges
    updateinars(dc,r)
    innerLoop(dc.fu,r,args...)
    writeoutars(dc,r)
    doprogress && next!(pm)
  end
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

function generateOutCube(::Type{T},eltype,oc::OutputCube,loopCacheSize) where T<:MmapCube
  oc.cube=MmapCube(oc.allAxes,folder=oc.folder,T=eltype,persist=false)
end
function generateOutCube(::Type{T},eltype,oc::OutputCube,loopCacheSize) where T<:CubeMem
  newsize=map(length,oc.allAxes)
  outar=Array{eltype}(undef,newsize...)
  genFun=oc.desc.genOut
  map!(_->genFun(eltype),outar,1:length(outar))
  oc.cube = Cubes.CubeMem(oc.allAxes,outar,zeros(UInt8,newsize...))
end

generateOutCubes(dc::DATConfig)=foreach(dc.outcubes) do c
  generateOutCube(c,dc.ispar,dc.max_cache,dc.loopCacheSize)
end
function generateOutCube(oc::OutputCube,ispar::Bool,max_cache,loopCacheSize)
  eltype,cubetype = getRetCubeType(oc,ispar,max_cache)
  generateOutCube(cubetype,eltype,oc,loopCacheSize)
end

dcg=nothing
function getCubeHandles(dc::DATConfig)
  if dc.ispar
    freshworkermodule()
    global dcg=dc
    passobj(1, workers(), [:dcg],from_mod=ESDL.DAT,to_mod=Main.PMDATMODULE)
    @everywhereelsem begin
      dc=Main.PMDATMODULE.dcg
      foreach(i->ESDL.DAT.allocatecachebuf(i,dc.loopCacheSize),dc.outcubes)
      foreach(i->ESDL.DAT.allocatecachebuf(i,dc.loopCacheSize),dc.incubes)
    end
  else
    foreach(i->allocatecachebuf(i,dc.loopCacheSize),dc.outcubes)
    foreach(i->allocatecachebuf(i,dc.loopCacheSize),dc.incubes)
  end
end

function allocatecachebuf(ic::Union{InputCube,OutputCube},loopcachesize) where N
  sl = ntuple(i->loopcachesize[i],length(ic.loopinds))
  s = (map(length,ic.axesSmall)...,sl...)
  ic.handle = MaskArray(zeros(eltype(ic.cube),s...),zeros(UInt8,s...))
end

function init_DATworkers()
  freshworkermodule()
end

function analyzeAxes(dc::DATConfig{NIN,NOUT}) where {NIN,NOUT}

  for cube in dc.incubes
    for a in caxes(cube.cube)
      in(a,cube.axesSmall) || in(a,dc.LoopAxes) || push!(dc.LoopAxes,a)
    end
  end
  length(dc.LoopAxes)==length(unique(map(typeof,dc.LoopAxes))) || error("Make sure that cube axes of different cubes match")
  for cube=dc.incubes
    myAxes = caxes(cube.cube)
    for (il,loopax) in enumerate(dc.LoopAxes)
      in(typeof(loopax),map(typeof,myAxes)) && push!(cube.loopinds,il)
    end
  end
  #Add output broadcast axes
  for outcube=dc.outcubes
    LoopAxesAdd=CubeAxis[]
    for (il,loopax) in enumerate(dc.LoopAxes)
      if !in(loopax,outcube.broadcastAxes)
        push!(outcube.loopinds,il)
        push!(LoopAxesAdd,loopax)
      end
    end
    outcube.allAxes=CubeAxis[outcube.axesSmall;LoopAxesAdd]
  end
  return dc
end

mysizeof(x)=sizeof(x)
mysizeof(x::Type{String})=1

"""
Function that compares two cache miss specifiers by their importance
"""
function cmpcachmisses(x1,x2)
  #First give preference to compressed misses
  if xor(x1.iscompressed,x2.iscompressed)
    return x1.iscompressed
  #Now compare the size of the miss multiplied with the inner size
  else
    return x1.cs * x1.innerleap > x2.cs * x2.innerleap
  end
end

function getCacheSizes(dc::DATConfig)

  if all(i->i.isMem,dc.incubes)
    dc.loopCacheSize=Int[length(x) for x in dc.LoopAxes]
    return dc
  end
  inAxlengths      = Vector{Int}[Int.(length.(cube.axesSmall)) for cube in dc.incubes]
  inblocksizes     = map((x,T)->isempty(x) ? mysizeof(eltype(T.cube)) : prod(x)*mysizeof(eltype(T.cube)),inAxlengths,dc.incubes)
  inblocksize,imax = findmax(inblocksizes)
  outblocksizes    = map(C->length(C.axesSmall)>0 ? sizeof(C.outtype)*prod(map(Int∘length,C.axesSmall)) : 1,dc.outcubes)
  outblocksize     = length(outblocksizes) > 0 ? findmax(outblocksizes)[1] : 1
  #Now add cache miss information for each input cube to every loop axis
  cmisses= NamedTuple{(:iloopax,:cs, :iscompressed, :innerleap),Tuple{Int64,Int64,Bool,Int64}}[]
  foreach(dc.LoopAxes,1:length(dc.LoopAxes)) do lax,ilax
    for ic in dc.incubes
      ii = findAxis(lax,ic.cube)
      if !isa(ii,Nothing)
        inax = isempty(ic.axesSmall) ? 1 : prod(map(length,ic.axesSmall))
        push!(cmisses,(iloopax = ilax,cs = cubechunks(ic.cube)[ii],iscompressed = iscompressed(ic.cube), innerleap=inax))
      end
    end
  end
  sort!(cmisses,lt=cmpcachmisses)
  #@show cmisses
  loopCacheSize    = getLoopCacheSize(max(inblocksize,outblocksize),map(length,dc.LoopAxes),dc.max_cache, cmisses)
  for cube in dc.incubes
    if !cube.isMem
      cube.cachesize = map(length,cube.axesSmall)
      for (cs,loopAx) in zip(loopCacheSize,dc.LoopAxes)
        in(typeof(loopAx),map(typeof,caxes(cube.cube))) && push!(cube.cachesize,cs)
      end
    end
  end
  dc.loopCacheSize=loopCacheSize
  return dc
end

"Calculate optimal Cache size to DAT operation"
function getLoopCacheSize(preblocksize,loopaxlengths,max_cache,cmisses)
  #@show preblocksize
  #@show cmisses
  totcachesize=max_cache

  incfac=totcachesize/preblocksize
  incfac<1 && error("The requested slices do not fit into the specified cache. Please consider increasing max_cache")
  loopCacheSize = ones(Int,length(loopaxlengths))
  # Go through list of cache misses first and decide
  imiss = 1
  while imiss<=length(cmisses)
    il = cmisses[imiss].iloopax
    s = min(cmisses[imiss].cs,loopaxlengths[il])/loopCacheSize[il]
    #Check if cache size is already set for this axis
    if loopCacheSize[il]==1
      if s<incfac
        loopCacheSize[il]=min(cmisses[imiss].cs,loopaxlengths[il])
        incfac=totcachesize/preblocksize/prod(loopCacheSize)
      else
        ii=floor(Int,incfac)
        while ii>1 && rem(s,ii)!=0
          ii=ii-1
        end
        loopCacheSize[il]=ii
        break
      end
    end
    imiss+=1
  end
  if imiss<length(cmisses)+1
    @warn "There are still cache misses"
    cmisses[imiss].iscompressed && @warn "There are compressed caches misses, you may want to use a different cube chunking"
  else
    #TODO continue increasing cache sizes on by one...
  end
  return loopCacheSize
end

function distributeLoopRanges(block_size::NTuple{N,Int},loopR::NTuple{N,Int},co) where N
    allranges = map(block_size,loopR,co) do bs,lr,cocur
      collect(filter(!isempty,[max(1,i):min(i+bs-1,lr) for i in (1-cocur):bs:lr]))
    end
    Iterators.product(allranges...)
end

function generateworkarrays(dc::DATConfig)
  if dc.ispar
    @everywhereelsem foreach(ESDL.DAT.setworkarray,PMDATMODULE.dc.incubes)
    @everywhereelsem foreach(ESDL.DAT.setworkarray,PMDATMODULE.dc.outcubes)
  else
    foreach(setworkarray,dc.incubes)
    foreach(setworkarray,dc.outcubes)
  end
end

using DataStructures: OrderedDict
using Base.Cartesian
@generated function innerLoop(f,loopRanges::T3,xin::NTuple{NIN,Any},xout::NTuple{NOUT,Any},filters,::InnerObj{T1,T2,T4,R,UPDOUT,LR},
  inwork,outwork,loopaxes::LAX,addargs,kwargs) where {T1,T2,T3,T4,R,NIN,NOUT,UPDOUT,LR,LAX}

  NinCol      = T1
  NoutCol     = T2
  nonbroadcastvars = T4
  Nloopvars   = length(T3.parameters)
  loopnames   = map(axname,LAX.parameters)
  loopRangesE = Expr(:block)
  inworksyms = map(i->Symbol(string("inwork_",i)),1:NIN)
  outworksyms= map(i->Symbol(string("outwork_",i)),1:NOUT)

  unrollEx = quote end
  [push!(unrollEx.args,:($(inworksyms[i]) = inwork[$i])) for i=1:NIN]
  [push!(unrollEx.args,:($(outworksyms[i]) = outwork[$i])) for i=1:NOUT]
  subIn = map(1:NIN) do i
    Expr(:call, :getSubRange2, inworksyms[i],  :(xin[$i]),  fill(:(:),NinCol[i])...,
      map(j->Symbol("i_$j"),nonbroadcastvars[i])...)
  end
  syncex = quote end
  subOut = Expr[]
  #Decide how to treat the output, create a view or copy in the end...
  for i=1:NOUT
    if !in(i,UPDOUT)
      ex = Expr(:call, :setSubRange2, outworksyms[i], :(xout[$i]), fill(:(:),NoutCol[i])...,
        map(j->Symbol("i_$j"),nonbroadcastvars[NIN+i])...)
      push!(subOut, ex)
    else
      rhs = Expr(:call, :getSubRange, :(xout[$i]),  fill(:(:),NoutCol[i])...,
        map(j->Symbol("i_$j"),nonbroadcastvars[NIN+i])...)
      push!(subIn,:($(outworksyms[i]) = $(rhs)[1]))
    end
  end
  for i=1:Nloopvars
    isym=Symbol("i_$(i)")
    if T3.parameters[i]==UnitRange{Int}
      pushfirst!(loopRangesE.args,:($isym=1:length(loopRanges[$i])))
    elseif T3.parameters[i]==Int
      pushfirst!(loopRangesE.args,:($isym=1:loopRanges[$i]))
    else
      error("Wrong Range argument")
    end
  end
  loopBody=quote end
  callargs=Any[:f,Expr(:parameters,Expr(:...,:kwargs))]
  R && foreach(j->push!(callargs,outworksyms[j]),1:NOUT)
  append!(loopBody.args,subIn)
  append!(callargs,inworksyms)
  if LR
    exloopdict = Expr(:tuple,[:($(QuoteNode(loopnames[il])) = ($(Symbol("i_$il")),loopaxes[$il].values[loopRanges($(Symbol("i_$il")))])) for il=1:Nloopvars]...)
    push!(loopBody.args,:(axdict = $exloopdict))
    push!(callargs,:axdict)
  end
  push!(callargs,Expr(:...,:addargs))
  runBody = quote end
  if R
    push!(runBody.args,Expr(:call,callargs...))
  else
    lhs = NOUT>1 ? Expr(:tuple,[:($(outworksyms[j])[:]) for j=1:NOUT]...) : :($(outworksyms[1])[:])
    rhs = Expr(:call,callargs...)
    push!(runBody.args,:($lhs.=$rhs))
  end
  #Add mask filter to loop body
  setzeroex = quote end
  foreach(i->push!(setzeroex.args,:($(outworksyms[i]).mask[:] .= mv)),1:NOUT)
  foreach(1:NIN) do i
    push!(loopBody.args,quote
      mv = docheck(filters[$i],$(inworksyms[i]))
      if !iszero(mv)
        $setzeroex
      else
        $runBody
      end
    end)
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

function getSubRange2(work,xin,cols...)
  #println(typeof(xin),cols)
  xview = getSubRange(xin,cols...)
  #println(xview,missrep,typeof(work))
  mask2miss(xview,work)
  return nothing
end

function setSubRange2(work,xout,cols...)
  xview = getSubRange(xout,cols...)
  miss2mask!(xview,work)
end

getSubRange(x::MaskArray,cols...) = MaskArray(view(x.data,cols...),view(x.mask,cols...))
getSubRange(x::Array,cols...)     = view(x,cols...)

"Calculate an axis permutation that brings the wanted dimensions to the front"
function getFrontPerm(dc::AbstractCubeData{T},dims) where T
  ax=caxes(dc)
  N=length(ax)
  perm=Int[i for i=1:length(ax)];
  iold=Int[]
  for i=1:length(dims) push!(iold,findAxis(dims[i],ax)) end
  iold2=sort(iold,rev=true)
  for i=1:length(iold) splice!(perm,iold2[i]) end
  perm=Int[iold;perm]
  return ntuple(i->perm[i],N)
end

include("dciterators.jl")
include("tablestats.jl")
end
