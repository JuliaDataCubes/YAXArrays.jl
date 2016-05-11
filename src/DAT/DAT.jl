module DAT
export @registerDATFunction, joinVars, DATdir
importall ..Cubes
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
importall ..CABLABTools
importall ..Cubes.TempCubes
import ...CABLAB
using Base.Dates
global const workdir=UTF8String["./"]
global const debugDAT=true

haskey(ENV,"CABLAB_WORKDIR") && (workdir[1]=ENV["CABLAB_WORKDIR"])

DATdir(x::AbstractString)=workdir[1]=x
DATdir()=workdir[1]


const fdimsin=Dict{UTF8String,Tuple}()
const fdimsout=Dict{UTF8String,Tuple}()
const fargs=Dict{UTF8String,Tuple}()

function Base.map{T}(fu::Function,cdata::AbstractCubeData{T},addargs...;max_cache=1e7,outfolder=joinpath(workdir[1],string(tempname()[2:end],fu)))

  isdir(outfolder) || mkpath(outfolder)
  axlist=axes(cdata)
  sfu=split(string(fu),".")[end]
  indims=collect(fdimsin[sfu])
  outdims=collect(fdimsout[sfu])

  #Test if we need to reshape
  reorder=false
  for (i,fi) in enumerate(indims)
    typeof(axlist[i])==fi || (reorder=true)
  end
  if reorder
    perm=getFrontPerm(cdata,indims)
    cdata=permutedims(cdata,perm)
    axlist=axlist[collect(perm)]
  end

  loopinR,loopOutR,loopR,inAxes,outAxes,LoopAxes,axlistOut = analyzeAxes(axlist,indims,outdims)

  ispar = nprocs()>1

  isMem = isa(cdata,AbstractCubeMem)

  ispar && !isMem && return run_disk_par(cdata, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut,outfolder,sfu,addargs)
  !ispar && !isMem && return run_disk_one(cdata, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut,outfolder,sfu,addargs)
  !ispar && isMem && return run_mem_one(cdata, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut,outfolder,sfu,addargs)
end

function init_DATworkers()
  freshworkermodule()
end

function run_disk_par(cdata::AbstractCubeData, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut, outfolder,sfu,addargs)

  loopCacheSize, CacheInSize = getLoopCacheSize(T,axlist,inAxes,outAxes,LoopAxes,max_cache,indims)

  tc=TempCube(axlistOut,CartesianIndex(totuple([map(length,outAxes);loopCacheSize])),folder=outfolder)
  global myExchangeObj
  myExchangeObj=(outfolder,T,cdata,CacheInSize,axlist,sfu,loopinR,loopOutR,addargs)
  try
    passobj(1, workers(), [:myExchangeObj],from_mod=CABLAB.DAT,to_mod=Main.PMDATMODULE)
  end
  @everywhereelsem outfolder,T,cdata,CacheInSize,axlist,sfu,loopinR,loopOutR,addargs=Main.PMDATMODULE.myExchangeObj
  @everywhereelsem tc=openTempCube(outfolder)
  @everywhereelsem tca=CachedArray(tc,1,tc.block_size,MaskedCacheBlock{T,length(tc.block_size.I)});
  @everywhereelsem cm=CachedArray(cdata,1,CartesianIndex(totuple(CacheInSize)),MaskedCacheBlock{T,length(axlist)});
  allRanges=distributeLoopRanges(tc.block_size.I[(end-length(loopR)+1):end],loopR)
  pmap(r->innerLoop(Val{Symbol(sfu)},Main.PMDATMODULE.cm,Main.PMDATMODULE.tca,CABLAB.DAT.totuple(Main.PMDATMODULE.loopinR),CABLAB.DAT.totuple(Main.PMDATMODULE.loopOutR),r,Main.PMDATMODULE.addargs),allRanges)
  @everywhereelsem CachedArrays.sync(tca)
  tc
end

function run_disk_one(cdata::AbstractCubeData, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut,outfolder,sfu,addargs)

  loopCacheSize, CacheInSize = getLoopCacheSize(T,axlist,inAxes,outAxes,LoopAxes,max_cache,indims)

  tc=TempCube(axlistOut,CartesianIndex(totuple([map(length,outAxes);loopCacheSize])),folder=outfolder)
  tca=CachedArray(tc,1,tc.block_size,MaskedCacheBlock{T,length(axlistOut)});
  cm=CachedArray(cdata,1,CartesianIndex(totuple(CacheInSize)),MaskedCacheBlock{T,length(axlist)});
  innerLoop(Val{Symbol(sfu)},cm,tca,totuple(loopinR),totuple(loopOutR),totuple(loopR),addargs)
  CachedArrays.sync(tca)
  tc
end

function run_mem_one(cdata::AbstractCubeData, T, axlist, inAxes, outAxes,LoopAxes, max_cache, indims, loopinR, loopOutR, loopR, axlistOut,outfolder,sfu,addargs)

  newsize=map(length,axlistOut)
  outCube = Cubes.CubeMem{T,length(newsize)}(axlistOut, zeros(T,newsize...),zeros(UInt8,newsize...))
  innerLoop(Val{Symbol(sfu)},cdata,outCube,totuple(loopinR),totuple(loopOutR),totuple(loopR),addargs)
  outCube
end

function analyzeAxes(axlist,indims,outdims)
  loopinR=[] #Values to pass to inner Loop
  loopOutR=[] #Values to pass to inner Loop
  loopR=[]   #Value to pass to inner Loop
  inAxes=[]  #Axes to be operated on
  outAxes=[] #Axes to be operated on
  LoopAxes=[] #Axes to loop over
  for a in axlist
    if typeof(a) in indims
      push!(loopinR,Colon())
      push!(inAxes,a)
    else
      push!(loopR,length(a))
      push!(LoopAxes,a)
    end
    if typeof(a) in outdims
      push!(outAxes,a)
      push!(loopOutR,Colon())
    end
  end
  axlistOut=CubeAxis[outAxes;LoopAxes]
  return loopinR,loopOutR,loopR,inAxes,outAxes,LoopAxes,axlistOut
end

"Calculate optimal Cache size to DAT operation"
function getLoopCacheSize(T,axlist,inAxes,outAxes,LoopAxes,max_cache,indims)
  totcachesize=max_cache
  inblocksize=length(inAxes)>0 ? sizeof(T)*prod(map(length,inAxes)) : 1
  outblocksize=length(outAxes)>0 ? sizeof(T)*prod(map(length,outAxes)) : 1
  incfac=totcachesize/max(inblocksize,outblocksize)
  incfac<1 && error("Not enough memory, please increase availabale cache size")
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
  j=1
  CacheInSize=Int[]
  for a in axlist
    if typeof(a) in indims
      push!(CacheInSize,length(a))
    else
      push!(CacheInSize,loopCacheSize[j])
      j=j+1
    end
  end
  @assert j==length(loopCacheSize)+1
  return loopCacheSize, CacheInSize
end

using Base.Cartesian
@generated function distributeLoopRanges{N}(block_size::NTuple{N,Int},loopR::Vector)
    quote
        @assert length(loopR)==N
        nsplit=Int[div(l,b) for (l,b) in zip(loopR,block_size)]
        baseR=UnitRange{Int}[1:b for b in block_size]
        a=Array(NTuple{$N,UnitRange{Int}},nsplit...)
        @nloops $N i a begin
            rr=@ntuple $N d->baseR[d]+(i_d-1)*block_size[d]
            @nref($N,a,i)=rr
        end
        a=reshape(a,length(a))
    end
end

@generated function innerLoop{fT,T1,T2,T3}(::Type{Val{fT}},xin,xout,loopinRanges::T1,loopoutRanges::T2,loopRanges::T3,addargs)
  NinCol=length(T1.parameters)
  NoutCol=length(T2.parameters)
  Nloopvars=length(T3.parameters)
  loopRangesE=Expr(:block)
  subIn=Expr(:call,:(CachedArrays.getSubRange),:xin,fill(:(:),NinCol)...)
  subOut=Expr(:call,:(CachedArrays.getSubRange),:xout,fill(:(:),NoutCol)...)
  for i=1:Nloopvars
    isym=Symbol("i_$(i)")
    push!(subIn.args,isym)
    push!(subOut.args,isym)
    if T3.parameters[i]==UnitRange{Int}
      unshift!(loopRangesE.args,:($isym=loopRanges[$i]))
    elseif T3.parameters[i]==Int
      unshift!(loopRangesE.args,:($isym=1:loopRanges[$i]))
    else
      error("Wrong Range argument")
    end
  end
  push!(subOut.args,Expr(:kw,:write,true))
  if length(subOut.args)>3
    loopBody=quote
      ain,min=$subIn
      aout,mout=$subOut
      Main.$(fT)(ain,aout,min,mout,addargs...)
    end
    #println(Expr(:for,loopRangesE,loopBody))
    return Expr(:for,loopRangesE,loopBody)
  else
    loopBody=quote
      ain,min=$subIn
      aout,mout=(xout[1],xout[2])
      Main.$(fT)(ain,aout,min,mout,addargs...)
    end
    return loopBody
  end
end

macro registerDATFunction(fname, dimsin,dimsout,args...)
    @assert dimsin.head==:tuple
    @assert dimsout.head==:tuple
    sfname=isa(esc(fname),Symbol) ? string(esc(fname)) : string(esc(fname).args[end])
    quote
        fdimsin[$sfname]=$dimsin
        fdimsout[$sfname]=$dimsout
        fargs[$sfname]=$args
    end
end


"Find a certain axis type in a vector of Cube axes"
function findAxis{T<:CubeAxis}(a::Type{T},v)
    for i=1:length(v)
        isa(v[i],a) && return i
    end
    return 0
end

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

"Function to join a Dict of several variables in a data cube to a single one."
function joinVars(d::Dict{UTF8String,Any})
  #First determine the common promote type of all variables
  vnames=collect(keys(d))
  typevec=DataType[eltype(d[vnames[i]]) for i in 1:length(vnames)]
  tcommon=reduce(promote_type,typevec[1],typevec)
  nold=prod(size(d[vnames[1]]))
  datanew=zeros(tcommon,nold*length(vnames))
  masknew=zeros(UInt8,nold*length(vnames))
  ipos=1
  for i=1:length(vnames)
    datanew[ipos:ipos+nold-1]=d[vnames[i]].data
    masknew[ipos:ipos+nold-1]=d[vnames[i]].mask
    ipos+=nold
  end
  CubeMem(CubeAxis[d[vnames[1]].axes;VariableAxis(vnames)],reshape(datanew,size(d[vnames[1]])...,length(vnames)),reshape(masknew,size(d[vnames[1]])...,length(vnames)))
end



end
