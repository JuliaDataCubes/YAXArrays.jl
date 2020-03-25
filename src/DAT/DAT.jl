module DAT
export mapCube
import ..Cubes
using ..ESDLTools
using Distributed: pmap, @everywhere, workers, remotecall_fetch, myid, nprocs
import ..Cubes: getAxis, cubechunks, iscompressed, chunkoffset,
  CubeAxis, AbstractCubeData, ESDLArray,
  caxes, findAxis, getsavefolder
import ..Cubes.Axes: AxisDescriptor, axname, ByInference, axsym, getOutAxis
import ..Datasets: Dataset
import ...ESDL
import ...ESDL.workdir
import Zarr: ZArray
import ProgressMeter: Progress, next!, progress_pmap
import Zarr: NoCompressor
using Dates
global const debugDAT=[false]
#TODO use a logging package
macro debug_print(e)
  debugDAT[1] && return(:(println($e)))
  :()
end

const hasparprogress=[false]
const progresscolor=[:cyan]

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
  handle::Any                #allocated cache
  workarray::Any
end

function InputCube(c::AbstractCubeData, desc::InDims)
  axesSmall = getAxis.(desc.axisdesc,Ref(c))
  any(isequal(nothing),axesSmall) && error("One of the input axes not found in input cubes")
  InputCube(c,desc,collect(CubeAxis,axesSmall),Int[],Int[],nothing,nothing)
end

createworkarrays(T,s,ntr)=[Array{T}(undef,s...) for i=1:ntr]




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
  innerchunks
  workarray::Any
  handle::Any                       #Cache to write the output to
  outtype
end

const InOutCube = Union{InputCube,OutputCube}

getsmallax(c::InOutCube)=c.axesSmall

getAxis(desc,c::InOutCube) = getAxis(desc,c.cube)

function setworkarray(c::InOutCube,ntr)
  wa = createworkarrays(eltype(c.cube),(length.(c.axesSmall)...,),ntr)
  c.workarray = map(wa) do w
    wrapWorkArray(c.desc.artype,w,c.axesSmall)
  end
end

function interpretoutchunksizes(desc,axesSmall,incubes)
  if desc.chunksize == :max
    map(length,axesSmall)
  elseif desc.chunksize == :input
    map(axesSmall) do ax
      for cc in incubes
        i = findAxis(axname(ax),cc)
        if i !== nothing
          return min(length(ax),cubechunks(cc)[i])
        end
      end
      return length(ax)
    end
  else
    desc.chunksize
  end
end

getOutAxis(desc::Tuple,inAxes,incubes,pargs,f)=map(i->getOutAxis(i,inAxes,incubes,pargs,f),desc)
function OutputCube(desc::OutDims,inAxes::Vector{CubeAxis},incubes,pargs,f)
  axesSmall     = getOutAxis(desc.axisdesc,inAxes,incubes,pargs,f)
  broadcastAxes = getOutAxis(desc.bcaxisdesc,inAxes,incubes,pargs,f)
  outtype       = getOuttype(desc.outtype,incubes)
  innerchunks   = interpretoutchunksizes(desc,axesSmall,incubes)
  OutputCube(nothing,desc,collect(CubeAxis,axesSmall),CubeAxis[],collect(CubeAxis,broadcastAxes),Int[],innerchunks,nothing,nothing,outtype)
end

"""
Configuration object of a DAT process. This holds all necessary information to perform the calculations.
It contains the following fields:

- `incubes::NTuple{NIN,InputCube}` The input data cubes
- `outcube::NTuple{NOUT,OutputCube}` The output data cubes
allInAxes     :: Vector
LoopAxes      :: Vector
ispar         :: Bool
loopcachesize :: Vector{Int}
max_cache
fu
inplace      :: Bool
include_loopvars:: Bool
ntr
addargs
kwargs
"""
mutable struct DATConfig{NIN,NOUT}
  "The input data cubes"
  incubes       :: NTuple{NIN,InputCube}

  outcubes      :: NTuple{NOUT,OutputCube}
  allInAxes     :: Vector
  LoopAxes      :: Vector
  ispar         :: Bool
  loopcachesize :: Vector{Int}
  max_cache
  fu
  inplace      :: Bool
  include_loopvars:: Bool
  ntr
  addargs
  kwargs
end
function DATConfig(cdata,indims,outdims,inplace,max_cache,fu,ispar,include_loopvars,nthreads,addargs,kwargs)

  isa(indims,InDims) && (indims=(indims,))
  isa(outdims,OutDims) && (outdims=(outdims,))
  length(cdata)==length(indims) || error("Number of input cubes ($(length(cdata))) differs from registration ($(length(indims)))")
  incubes  = ([InputCube(o[1],o[2]) for o in zip(cdata,indims)]...,)
  allInAxes = vcat([ic.axesSmall for ic in incubes]...)
  outcubes = ((map(1:length(outdims),outdims) do i,desc
     OutputCube(desc,allInAxes,cdata,addargs,fu)
  end)...,)

  DATConfig(
    incubes,
    outcubes,
    allInAxes,
    CubeAxis[],                                 # LoopAxes
    ispar,
    Int[],
    max_cache,                                  # max_cache
    fu,                                         # fu                                      # loopcachesize
    inplace,                                    # inplace
    include_loopvars,
    nthreads,
    addargs,                                    # addargs
    kwargs
  )
end


getOuttype(outtype::Int,cdata)=eltype(cdata[outtype])
function getOuttype(outtype::DataType,cdata)
  outtype
end

mapCube(fu::Function,cdata::AbstractCubeData,addargs...;kwargs...)=mapCube(fu,(cdata,),addargs...;kwargs...)

function mapCube(f, in_ds::Dataset, addargs...; indims=InDims(), outdims=OutDims(), inplace=true, kwargs...)
    allars = values(in_ds.cubes)
    allaxes = collect(values(in_ds.axes))
    arnames = keys(in_ds.cubes)
    sarnames = (arnames...,)
    any(ad->findAxis(ad,allaxes)===nothing,indims.axisdesc) && error("One of the Dimensions does not exist in Dataset")

    idar = collect(indims.axisdesc)
    allindims = map(allars) do c
        idshort = filter(idar) do ad
            findAxis(ad,c)!==nothing
        end
        InDims((idshort...,), indims.artype, indims.procfilter)
    end
    isa(outdims, OutDims) || error("Only one output cube currently supported for datasets")
    isempty(addargs) || error("Additional arguments currently not supported for datasets, use kwargs instead")
    if inplace
        fnew = let arnames=collect(arnames), f=f
            function dsfun(xout,xin...; kwargs...)
                incubes = NamedTuple{sarnames, typeof(xin)}(xin)
                f(xout,incubes; kwargs...)
            end
        end
    else
        fnew = let arnames=collect(arnames), f=f
            function dsfun(xin...; kwargs...)
                incubes = NamedTuple{sarnames, typeof(xin)}(xin)
                f(incubes; kwargs...)
            end
        end
    end
    allcubes = collect(values(in_ds.cubes))
    mapCube(fnew,(allcubes...,);indims=allindims,outdims=outdims, inplace=inplace, kwargs...)
end

import Base.mapslices
function mapslices(f,d::Union{AbstractCubeData, Dataset},addargs...;dims,kwargs...)
    isa(dims,String) && (dims=(dims,))
    mapCube(f,d,addargs...;indims = InDims(dims...),outdims = OutDims(ByInference()),inplace=false,kwargs...)
end



"""
    mapCube(fun, cube, addargs...;kwargs)

Map a given function `fun` over slices of the data cube `cube`.

### Keyword arguments

* `max_cache=1e7` maximum size of blocks that are read into memory, defaults to approx 10Mb
* `indims::InDims` List of input cube descriptors of type [`InDims`](@ref) for each input data cube
* `outdims::OutDims` List of output cube descriptors of type [`OutDims`](@ref) for each output cube
* `inplace` does the function write to an output array inplace or return a single value> defaults to `true`
* `ispar` boolean to determine if parallelisation should be applied, defaults to `true` if workers are available.
* `showprog` boolean indicating if a ProgressMeter shall be shown
* `include_loopvars` boolean to indicate if the varoables looped over should be added as function arguments
* `kwargs` additional keyword arguments passed to the inner function

The first argument is always the function to be applied, the second is the input cube or
a tuple input cubes if needed.
"""
function mapCube(fu::Function,
    cdata::Tuple,addargs...;
    max_cache=ESDL.ESDLDefaults.max_cache[],
    indims=InDims(),
    outdims=OutDims(),
    inplace=true,
    ispar=nprocs()>1,
    debug=false,
    include_loopvars=false,
    showprog=true,
    nthreads=ispar ? Dict(i=>remotecall_fetch(Threads.nthreads,i) for i in workers()) : [Threads.nthreads()] ,
    kwargs...)
  @debug_print "Check if function is registered"
  @debug_print "Generating DATConfig"
  dc=DATConfig(cdata,indims,outdims,inplace,
    max_cache,fu,ispar,include_loopvars,nthreads,addargs,kwargs)
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
  runLoop(dc,showprog)
  @debug_print "Finalizing Output Cube"

  if length(dc.outcubes)==1
    return dc.outcubes[1].desc.finalizeOut(dc.outcubes[1].cube)
  else
    return (map(i->i.desc.finalizeOut(i.cube),dc.outcubes)...,)
  end

end

function makeinplace(f)
  (args...;kwargs...)->begin
    first(args).=f(Base.tail(args)...;kwargs...)
    nothing
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

function getchunkoffsets(dc::DATConfig)
  co = zeros(Int,length(dc.LoopAxes))
  lc = dc.loopcachesize
  for ic in dc.incubes
    #@show chunkoffset
    for (ax,cocur,cs) in zip(caxes(ic.cube),chunkoffset(ic.cube),cubechunks(ic.cube))
      ii = findAxis(ax,dc.LoopAxes)
      if !isa(ii,Nothing) && iszero(co[ii]) && cocur>0 && mod(lc[ii],cs)==0
        co[ii]=cocur
      end
    end
  end
  (co...,)
end

updatears(clist,r,f) = foreach(clist) do ic
  updatear(f,r, ic.cube,length(ic.axesSmall), ic.loopinds, ic.handle )
end
function updatear(f,r,cube,ncol,loopinds,handle)
  indscol = ntuple(i->1:size(cube,i),ncol)
  indsr   = ntuple(i->r[loopinds[i]],length(loopinds))
  indsall = (indscol...,indsr...)
  if size(handle) != length.(indsall)
    hinds = map(i->1:length(i),indsall)
    if f == :read
      handle[hinds...] = cube.data[indsall...]
    else
      cube.data[indsall...] = handle[hinds...]
    end
  else
    if f == :read
      handle[:] = cube.data[indsall...]
    else
      cube.data[indsall...] = handle
    end
  end
end
updateinars(dc,r)=updatears(dc.incubes,r,:read)
writeoutars(dc,r)=updatears(dc.outcubes,r,:write)

function runLoop(dc::DATConfig,showprog)
  allRanges=distributeLoopRanges((dc.loopcachesize...,),(map(length,dc.LoopAxes)...,),getchunkoffsets(dc))
  #@show collect(allRanges)
  if dc.ispar
    pmapfun = showprog ? progress_pmap : pmap
    pmapfun(runLooppar,allRanges)
  else
    runLoop(dc,allRanges,showprog)
  end
  dc.outcubes
end

function runLooppar(allRanges)
  dc = Main.PMDATMODULE.dc
  runLoop(dc,(allRanges,),false)
end

abstract type AxValCreator end
struct NoLoopAxes <:AxValCreator end
struct AllLoopAxes{S,V} <:AxValCreator
  loopsyms::S
  loopaxvals::V
end
AllLoopAxes(a) = AllLoopAxes(map(axsym,a), map(i->i.values,a))
getlaxvals(::NoLoopAxes,cI,offscur) = ()
getlaxvals(a::AllLoopAxes,cI,offscur) = (NamedTuple{a.loopsyms}(map((ax,i,of)->(i+of,ax[i+of]),a.loopaxvals,cI.I, offscur)),)


function getallargs(dc::DATConfig)
  inars = map(ic->ic.handle,dc.incubes)
  outars = map(ic->ic.handle,dc.outcubes)
  filters = map(ic->ic.desc.procfilter,dc.incubes)
  inworkar = (map(i->i.workarray,dc.incubes)...,)
  outworkar = (map(i->i.workarray,dc.outcubes)...,)
  axvals = if dc.include_loopvars
    lax = (dc.LoopAxes...,)
    AllLoopAxes(lax)
  else
    NoLoopAxes()
  end
  adda = dc.addargs
  kwa = dc.kwargs
  fu = if !dc.inplace
    makeinplace(dc.fu)
  else
    dc.fu
  end
  inarsbc = map(dc.incubes) do ic
    allax = falses(length(dc.LoopAxes))
    allax[ic.loopinds].=true
    PickAxisArray(ic.handle,allax,ncol=length(ic.axesSmall))
  end
  outarsbc = map(dc.outcubes) do oc
    allax = falses(length(dc.LoopAxes))
    allax[oc.loopinds].=true
    PickAxisArray(oc.handle,allax,ncol=length(oc.axesSmall))
  end
  (fu,inars,outars,inarsbc,outarsbc,filters,inworkar,outworkar,
  axvals,adda,kwa)
end

function runLoop(dc::DATConfig, allRanges, showprog)
  allargs = getallargs(dc)
  runLoopArgs(dc,allargs,allRanges,showprog)
end

@noinline function runLoopArgs(dc,args,allRanges,doprogress)
  doprogress && (pm = Progress(length(allRanges)))
  for r in allRanges
    updateinars(dc,r)
    innerLoop(r,args...)
    writeoutars(dc,r)
    doprogress && next!(pm)
  end
end

function getRetCubeType(oc,ispar,max_cache)
  eltype=Union{typeof(oc.desc.genOut(oc.outtype)),Missing}
  outsize=sizeof(eltype)*(length(oc.allAxes)>0 ? prod(map(length,oc.allAxes)) : 1)
  if string(oc.desc.retCubeType)=="auto"
    if ispar || outsize>max_cache
      cubetype = ZArray
    else
      cubetype = Array
    end
  else
    cubetype = oc.desc.retCubeType
  end
  eltype,cubetype
end

function generateOutCube(::Type{T},eltype,oc::OutputCube,loopcachesize,co) where T<:ZArray
  cs_inner = oc.innerchunks
  cs = (cs_inner..., loopcachesize...)
  folder = getsavefolder(oc.desc.path)
  oc.cube=ZArrayCube(oc.allAxes,folder=folder,T=eltype,persist=oc.desc.persist,chunksize=cs,chunkoffset=co,compressor=oc.desc.compressor)
end
function generateOutCube(::Type{T},eltype,oc::OutputCube,loopcachesize,co) where T<:Array
  newsize=map(length,oc.allAxes)
  outar=Array{eltype}(undef,newsize...)
  genFun=oc.desc.genOut
  map!(_->genFun(eltype),outar,1:length(outar))
  oc.cube = ESDLArray(oc.allAxes,outar)
end

function generateOutCubes(dc::DATConfig)
  co = getchunkoffsets(dc)
  foreach(dc.outcubes) do c
    co2 = (zeros(Int,length(c.axesSmall))...,co...)
    generateOutCube(c,dc.ispar,dc.max_cache,dc.loopcachesize,co2)
  end
end
function generateOutCube(oc::OutputCube,ispar::Bool,max_cache,loopcachesize,co)
  eltype,cubetype = getRetCubeType(oc,ispar,max_cache)
  generateOutCube(cubetype,eltype,oc,loopcachesize,co)
end

dcg=nothing
function getCubeHandles(dc::DATConfig)
  if dc.ispar
    freshworkermodule()
    global dcg=dc
    passobj(1, workers(), [:dcg],from_mod=ESDL.DAT,to_mod=Main.PMDATMODULE)
    @everywhereelsem begin
      dc=Main.PMDATMODULE.dcg
      foreach(i->ESDL.DAT.allocatecachebuf(i,dc.loopcachesize),dc.outcubes)
      foreach(i->ESDL.DAT.allocatecachebuf(i,dc.loopcachesize),dc.incubes)
    end
  else
    foreach(i->allocatecachebuf(i,dc.loopcachesize),dc.outcubes)
    foreach(i->allocatecachebuf(i,dc.loopcachesize),dc.incubes)
  end
end

function allocatecachebuf(ic::Union{InputCube,OutputCube},loopcachesize) where N
  sl = ntuple(i->loopcachesize[ic.loopinds[i]],length(ic.loopinds))
  s = (map(length,ic.axesSmall)...,sl...)
  ic.handle = zeros(eltype(ic.cube),s...)
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
    # for oc in dc.outcubes
    #   cs = oc.desc.chunksize
    #   if cs !== nothing
    #     ii = findAxis(lax,oc.allAxes)
    #     if !isa(ii,Nothing)
    #       innerleap = prod(cs)
    #       push!(cmisses,(iloopax = ilax,cs = cs[ii],iscompressed = isa(oc.desc.compressor,NoCompressor), innerleap=innerleap))
    #     end
    #   end
    # end
  end
  sort!(cmisses,lt=cmpcachmisses)
  #@show cmisses
  loopcachesize    = getLoopCacheSize(max(inblocksize,outblocksize),map(length,dc.LoopAxes),dc.max_cache, cmisses)
  for cube in dc.incubes
    cube.cachesize = map(length,cube.axesSmall)
    for (cs,loopAx) in zip(loopcachesize,dc.LoopAxes)
      in(typeof(loopAx),map(typeof,caxes(cube.cube))) && push!(cube.cachesize,cs)
    end
  end
  dc.loopcachesize=loopcachesize
  return dc
end

"Calculate optimal Cache size to DAT operation"
function getLoopCacheSize(preblocksize,loopaxlengths,max_cache,cmisses)
  #@show preblocksize
  #@show cmisses
  totcachesize=max_cache

  incfac=totcachesize/preblocksize
  incfac<1 && error("The requested slices do not fit into the specified cache. Please consider increasing max_cache")
  loopcachesize = ones(Int,length(loopaxlengths))
  # Go through list of cache misses first and decide
  imiss = 1
  while imiss<=length(cmisses)
    il = cmisses[imiss].iloopax
    s = min(cmisses[imiss].cs,loopaxlengths[il])/loopcachesize[il]
    #Check if cache size is already set for this axis
    if loopcachesize[il]==1
      if s<incfac
        loopcachesize[il]=min(cmisses[imiss].cs,loopaxlengths[il])
        incfac=totcachesize/preblocksize/prod(loopcachesize)
      else
        ii=floor(Int,incfac)
        while ii>1 && rem(s,ii)!=0
          ii=ii-1
        end
        loopcachesize[il]=ii
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
  return loopcachesize
end

function distributeLoopRanges(block_size::NTuple{N,Int},loopR::NTuple{N,Int},co) where N
    allranges = map(block_size,loopR,co) do bs,lr,cocur
      collect(filter(!isempty,[max(1,i):min(i+bs-1,lr) for i in (1-cocur):bs:lr]))
    end
    Iterators.product(allranges...)
end

function generateworkarrays(dc::DATConfig)
  if dc.ispar
    @everywhereelsem foreach(i->ESDL.DAT.setworkarray(i,PMDATMODULE.dc.ntr[Distributed.myid()]),PMDATMODULE.dc.incubes)
    @everywhereelsem foreach(i->ESDL.DAT.setworkarray(i,PMDATMODULE.dc.ntr[Distributed.myid()]),PMDATMODULE.dc.outcubes)
  else
    foreach(i->setworkarray(i,dc.ntr[1]),dc.incubes)
    foreach(i->setworkarray(i,dc.ntr[1]),dc.outcubes)
  end
end

macro innercode()
  esc(quote
    ithr = Threads.threadid()
    #Pick the correct array according to thread
    myinwork = map(i->i[ithr],inwork)
    myoutwork = map(i->i[ithr],outwork)
    #Copy data into work arrays
    foreach((iw,x)->iw.=view(x,cI.I...),myinwork,xinBC)
    #Apply filters
    mvs = map(docheck,filters,myinwork)
    if any(mvs)
      # Set all outputs to missing
      foreach(ow->fill!(ow,missing),myoutwork)
    else
      #Compute loop axis values if necessary
      laxval = getlaxvals(axvalcreator,cI,offscur)
      #Finally call the function
      f(myoutwork...,myinwork...,laxval...,addargs...;kwargs...)
    end
    #Copy data into output array
    foreach((iw,x)->view(x,cI.I...).=iw,myoutwork,xoutBC)
  end)
end

using DataStructures: OrderedDict
using Base.Cartesian
@noinline function innerLoop(loopRanges,f,xin,xout,xinBC,xoutBC,filters,
  inwork,outwork,axvalcreator,addargs,kwargs)
  offscur = map(i->(first(i)-1), loopRanges)
  if length(inwork[1])==1
    for cI in CartesianIndices(map(i->1:length(i),loopRanges))
      @innercode
    end
  else
    Threads.@threads for cI in CartesianIndices(map(i->1:length(i),loopRanges))
      @innercode
    end
  end
end


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
