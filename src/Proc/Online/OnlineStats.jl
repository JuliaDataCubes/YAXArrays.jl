module DATOnlineStats
using OnlineStats
using Combinatorics
importall ..DAT
importall ..Cubes
importall ..Mask
import ...ESDLTools.totuple
import NamedTuples
import OnlineStats: VectorOb
export DATfitOnline


function DATfitOnline(xout::AbstractArray{T},ain,cfun) where T<:OnlineStat{Number}
  xin,maskin = ain
  for (mi,xi) in zip(maskin,xin)
    (mi & MISSING)==VALID && fit!(xout[1],xi)
  end
end

function DATfitOnline(xout::AbstractArray{T},ain,spl,cfun) where T<:OnlineStat{Number}
  xin,maskin = ain
  splitmask,msplitmask = spl
  for (mi,xi,si,m2) in zip(maskin,xin,splitmask,msplitmask)
      ((mi | m2) & MISSING)==VALID && fit!(xout[cfun(si)],Float64(xi))
  end
end

function DATfitOnline(xout::AbstractArray{S},ain,cfun) where S<:OnlineStat{VectorOb}
  xin,maskin = ain
    offs=1
    offsinc=size(xin,1)
    xtest=zeros(Float64,offsinc)
    mtest=zeros(UInt8,offsinc)
    for offsin=1:offsinc:length(xin)
        for j=1:offsinc
          xtest[j]=xin[offsin+j-1]
          mtest[j]=maskin[offsin+j-1]
        end
        all(m->(m & MISSING)==VALID,mtest) && fit!(xout[1],xtest)
    end
end

function DATfitOnline(xout::AbstractArray{S},ain,spl,cfun) where S<:OnlineStat{VectorOb}
  xin,maskin = ain
  splitmask,msplitmask = spl
  offs=1
  offsinc=size(xin,1)
  xtest=zeros(eltype(xin),offsinc)
  mtest=zeros(UInt8,offsinc)
  for (offsin,si) in zip(1:offsinc:length(xin),1:length(splitmask))
    copy!(xtest,1,xin,offsin,offsinc)
    copy!(mtest,1,maskin,offsin,offsinc)
    ((msplitmask[si] & MISSING)==VALID) && all(m->(m & MISSING)==VALID,mtest) && fit!(xout[cfun(splitmask[si])],xtest)
  end
end

function finalizeOnlineCube(c::CubeMem)
    CubeMem(c.axes,map(i->nobs(i)>0 ? OnlineStats.value(i) : NaN,c.data),c.mask)
end

function finalizeOnlineCube(c::CubeMem,varAx::CubeAxis, statType::Type{T}) where {T<:CovMatrix}
  nV=length(varAx)
  cout=zeros(Float32,nV,nV,size(c.data)...)
  maskout=zeros(UInt8,nV,nV,size(c.data)...)
  cout2 = zeros(Float32,nV,size(c.data)...)
  maskout2=zeros(UInt8,nV,size(c.data)...)
  for ii in CartesianIndices(size(c.data))
    cout[:,:,ii]=OnlineStats.value(c.data[ii])
    maskout[:,:,ii]=c.mask[ii]
    cout2[:,ii]=OnlineStats.mean(c.data[ii].b)
    maskout2[:,ii]=c.mask[ii]
  end
  varAx1 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 1"),varAx.values) : RangeAxis(string(axname(varAx)," 1"),varAx.values)
  varAx2 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 2"),varAx.values) : RangeAxis(string(axname(varAx)," 2"),varAx.values)
  CubeMem(CubeAxis[varAx1,varAx2,c.axes...],cout,maskout),CubeMem(CubeAxis[varAx,c.axes...],cout2,maskout2)
end

function finalizeOnlineCube(c::CubeMem,varAx::CubeAxis,statType::Type{T}) where {T<:KMeans}
  nV,nC=size(OnlineStats.value(c.data[1]))
  cout=zeros(Float32,nV,nC,size(c.data)...)
  maskout=zeros(UInt8,nV,nC,size(c.data)...)
  for ii in CartesianIndices(size(c.data))
    cout[:,:,ii]=OnlineStats.value(c.data[ii])
    maskout[:,:,ii]=c.mask[ii]
  end
  classAx=CategoricalAxis("Class",["Class $i" for i=1:nC])
  CubeMem(CubeAxis[varAx,classAx,c.axes...],cout,maskout)
end

getGenFun(f::Type{T},pargs...) where {T<:OnlineStat}=i->f()
function getGenFun(f::Type{T},nclass,d) where T<:OnlineStats.KMeans
  return i->begin Random.seed!(190283);f(d,nclass) end
end
function getGenFun(f::Type{T},nclass,startVal,d) where T<:OnlineStats.KMeans
  return i->begin a=f(d,nclass);a.value[:]=startVal;a end
end
function getGenFun(f::Type{T},pargs...) where T<:OnlineStats.CovMatrix
  return i->f(pargs[1])
end

getFinalFun(f::Type{T},funargs...) where {T<:OnlineStat}=finalizeOnlineCube
getFinalFun(f::Type{T},funargs...) where {T<:OnlineStats.KMeans}=c->finalizeOnlineCube(c,funargs[1],T)
getFinalFun(f::Type{T},funargs...) where {T<:OnlineStats.CovMatrix}=c->finalizeOnlineCube(c,funargs[1],T)

function mapCube(f::Type{T},cdata::AbstractCubeData,pargs...;by=CubeAxis[],max_cache=1e7,cfun=identity,outAxis=nothing,MDAxis=Nothing,kwargs...) where T<:OnlineStat
  inAxes=axes(cdata)
  #Now analyse additional by axes
  inaxtypes=map(typeof,inAxes)
  if T <:OnlineStat{VectorOb}
    MDAxis<:Nothing && error("$T Requires a Vector Input, you have to specify the MDAxis keyword argument.")
    MDAxis <:CubeAxis || error("MDAxis must be an Axis type")
    mdAx = getAxis(MDAxis,inAxes)
    ia1 = [MDAxis]
    lout=length(mdAx)
    pargs=(pargs...,lout)
    funargs = (mdAx,)
  else
    lout=1
    ia1 = CubeAxis[]
    funargs = ()
  end
  function interpretBycubes(x::Union{String,Type},c)
    i=findAxis(x,axes(c))
    axes(c)[i]
  end
  function interpretBycubes(x::AbstractCubeData,c)
    x
  end
  by2 = map(a->interpretBycubes(a,cdata),by)
  bycubes=filter(i->!isa(i,CubeAxis),collect(by2))
  byaxes =filter(i->isa(i,CubeAxis),collect(by2))
  if length(bycubes)==1
    if outAxis==nothing
      if haskey(bycubes[1].properties,"labels")
        idict=bycubes[1].properties["labels"]
        axname=get(bycubes[1].properties,"name","Label")
        outAxis=CategoricalAxis(axname,collect(String,values(idict)))
        convertdict=Dict(k=>i for (i,k) in enumerate(keys(idict)))
        cfun=x->convertdict[x]
      else
        error("You have to specify an output axis")
      end
    end
    indata=(cdata,bycubes[1])
    isa(outAxis,DataType) && (outAxis=outAxis())
    outdims=[get_descriptor(outAxis)]
    lout=lout * length(outAxis)
    inAxes2=filter(i->!in(i,by2) && in(i,axes(bycubes[1])) && !isa(i,MDAxis),inAxes)
  elseif length(bycubes)>1
    error("more than one filter cube not yet supported")
  else
    indata=cdata
    lout=lout * 1
    outdims=[]
    inAxes2=filter(i->!in(i,byaxes) && !isa(i,MDAxis),inAxes)
  end
  axcombs=combinations(inAxes2)
  totlengths=map(a->prod(map(length,a)),axcombs)*sizeof(Float32)*lout
  smallenough=totlengths.<max_cache
  axcombs=[ax for ax in axcombs][smallenough]
  totlengths=totlengths[smallenough]
  if !isempty(totlengths)
    m,i=findmax(totlengths)
    iain=[ia1;map(typeof,axcombs[i])]
    ia  = map(typeof,axcombs[i])
    outBroad=filter(ax->!in(ax,byaxes) && !in(typeof(ax),iain),inAxes)
    indims=isempty(bycubes) ? [get_descriptor.(iain)] : [get_descriptor.(iain),get_descriptor.(ia)]
  else
    outBroad=filter(ax->!in(ax,byaxes),inAxes)
    indims=isempty(bycubes) ? [get_descriptor.(ia1)] : [get_descriptor.(ia1),[]]
  end
  outBroad=map(get_descriptor,outBroad)
  fout(x) = getGenFun(f,pargs...)(x)
  ic = ntuple(i->InDims(indims[i]...,miss=MaskMissing()),length(indims))
  oc = OutDims(outdims...,bcaxisdesc=outBroad,finalizeOut=getFinalFun(f,funargs...),genOut=fout,outtype=typeof(fout(f)),miss=NoMissing(),update=true)
  return mapCube(DATfitOnline,indata,cfun;
    indims = ic,outdims = oc,
    kwargs...
)
end

include("OnlinePCA.jl")
include("OnlineHist.jl")
end
