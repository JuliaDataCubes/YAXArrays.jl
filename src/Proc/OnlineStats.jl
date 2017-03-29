module DATOnlineStats
using OnlineStats
using Combinatorics
importall ..DAT
importall ..Cubes
importall ..Mask
import ...CABLABTools.totuple
export DATfitOnline


function DATfitOnline{T<:OnlineStat{OnlineStats.ScalarInput}}(xout::AbstractArray{T},maskout,xin,maskin,cfun)
    for (mi,xi) in zip(maskin,xin)
        (mi & MISSING)==VALID && fit!(xout[1],xi)
    end
end

function DATfitOnline{T<:OnlineStat{OnlineStats.ScalarInput}}(xout::AbstractArray{T},maskout,xin,maskin,splitmask,msplitmask,cfun)
  for (mi,xi,si,m2) in zip(maskin,xin,splitmask,msplitmask)
      ((mi | m2) & MISSING)==VALID && fit!(xout[cfun(si)],xi)
  end
end

function DATfitOnline{T<:OnlineStat{OnlineStats.VectorInput},U}(xout::AbstractArray{T},maskout,xin::AbstractArray{U},maskin,cfun)
    offs=1
    offsinc=size(xin,1)
    xtest=zeros(U,offsinc)
    mtest=zeros(UInt8,offsinc)
    for offsin=1:offsinc:length(xin)
        for j=1:offsinc
          xtest[j]=xin[offsin+j-1]
          mtest[j]=maskin[offsin+j-1]
        end
        all(m->(m & MISSING)==VALID,mtest) && fit!(xout[1],xtest)
    end
end

function DATfitOnline{T<:OnlineStat{OnlineStats.VectorInput},U}(xout::AbstractArray{T},maskout,xin::AbstractArray{U},maskin,splitmask,msplitmask,cfun)
  offs=1
  offsinc=size(xin,1)
  xtest=zeros(U,offsinc)
  mtest=zeros(UInt8,offsinc)
  for (offsin,si) in zip(1:offsinc:length(xin),1:length(splitmask))
    copy!(xtest,1,xin,offsin,offsinc)
    copy!(mtest,1,maskin,offsin,offsinc)
    ((msplitmask[si] & MISSING)==VALID) && all(m->(m & MISSING)==VALID,mtest) && fit!(xout[cfun(splitmask[si])],xtest)
  end
end

function finalizeOnlineCube{T<:OnlineStat,N}(c::CubeMem{T,N})
    CubeMem(c.axes,map(i->nobs(i)>0 ? OnlineStats.value(i) : NaN,c.data),c.mask)
end

function finalizeOnlineCube{T<:OnlineStats.CovMatrix,CT,S}(c::CubeMem{T},varAx::CubeAxis{CT,S})
  nV=length(varAx)
  cout=zeros(Float32,nV,nV,size(c.data)...)
  maskout=zeros(UInt8,nV,nV,size(c.data)...)
  cout2 = zeros(Float32,nV,size(c.data)...)
  maskout2=zeros(UInt8,nV,size(c.data)...)
  for ii in CartesianRange(size(c.data))
    cout[:,:,ii]=OnlineStats.value(c.data[ii])
    maskout[:,:,ii]=c.mask[ii]
    cout2[:,ii]=OnlineStats.mean(c.data[ii])
    maskout2[:,ii]=c.mask[ii]
  end
  varAx1 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 1"),varAx.values) : RangeAxis(string(axname(varAx)," 1"),varAx.values)
  varAx2 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 2"),varAx.values) : RangeAxis(string(axname(varAx)," 2"),varAx.values)
  CubeMem(CubeAxis[varAx1,varAx2,c.axes...],cout,maskout),CubeMem(CubeAxis[varAx,c.axes...],cout2,maskout2)
end

function finalizeOnlineCube{T<:OnlineStats.KMeans,N}(c::CubeMem{T,N},varAx::CubeAxis)
  nV,nC=size(c.data[1].value)
  cout=zeros(Float32,nV,nC,size(c.data)...)
  maskout=zeros(UInt8,nV,nC,size(c.data)...)
  for ii in CartesianRange(size(c.data))
    cout[:,:,ii]=OnlineStats.value(c.data[ii])
    maskout[:,:,ii]=c.mask[ii]
  end
  classAx=CategoricalAxis("Class",["Class $i" for i=1:nC])
  CubeMem(CubeAxis[varAx,classAx,c.axes...],cout,maskout)
end

getGenFun{T<:OnlineStat}(f::Type{T},pargs...)=i->f()
function getGenFun{T<:OnlineStats.KMeans}(f::Type{T},nclass,d)
  return i->begin srand(190283);f(d,nclass) end
end
function getGenFun{T<:OnlineStats.KMeans}(f::Type{T},nclass,startVal,d)
  return i->begin a=f(d,nclass);a.value[:]=startVal;a end
end
function getGenFun{T<:OnlineStats.CovMatrix}(f::Type{T},pargs...)
  return i->f(pargs[1],EqualWeight())
end

getFinalFun{T<:OnlineStat}(f::Type{T},funargs...)=finalizeOnlineCube
getFinalFun{T<:OnlineStats.KMeans}(f::Type{T},funargs...)=c->finalizeOnlineCube(c,funargs[1])
getFinalFun{T<:OnlineStats.CovMatrix}(f::Type{T},funargs...)=c->finalizeOnlineCube(c,funargs[1])


function mapCube{T<:OnlineStat}(f::Type{T},cdata::AbstractCubeData,pargs...;by=CubeAxis[],max_cache=1e7,cfun=identity,outAxis=nothing,MDAxis=Void,kwargs...)
  inAxes=axes(cdata)
  #Now analyse additional by axes
  inaxtypes=map(typeof,inAxes)
  if issubtype(T,OnlineStat{OnlineStats.VectorInput})
    MDAxis<:Void && error("$T Requires a Vector Input, you have to specify the MDAxis keyword argument.")
    issubtype(MDAxis,CubeAxis) || error("MDAxis must be an Axis type")
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
  bycubes=filter(i->!in(i,inaxtypes),collect(by))
  if length(bycubes)==1
    if outAxis==nothing
      if haskey(bycubes[1].properties,"labels")
        idict=bycubes[1].properties["labels"]
        axname=get(bycubes[1].properties,"name","Label")
        outAxis=CategoricalAxis(axname,collect(String,values(idict)))
        const convertdict=Dict(k=>i for (i,k) in enumerate(keys(idict)))
        cfun=x->convertdict[x]
      else
        error("You have to specify an output axis")
      end
    end
    indata=(cdata,bycubes[1])
    isa(outAxis,DataType) && (outAxis=outAxis())
    outdims=(outAxis,)
    lout=lout * length(outAxis)
    inAxes2=filter(i->!in(typeof(i),by) && in(i,axes(bycubes[1])) && !isa(i,MDAxis),inAxes)
  elseif length(bycubes)>1
    error("more than one filter cube not yet supported")
  else
    indata=cdata
    lout=lout * 1
    outdims=()
    inAxes2=filter(i->!in(typeof(i),by) && !isa(i,MDAxis),inAxes)
  end
  axcombs=combinations(inAxes2)
  totlengths=map(a->prod(map(length,a)),axcombs)*sizeof(Float32)*lout
  smallenough=totlengths.<max_cache
  axcombs=collect(axcombs)[smallenough]
  totlengths=totlengths[smallenough]
  if !isempty(totlengths)
    m,i=findmax(totlengths)
    iain=[ia1;map(typeof,axcombs[i])]
    ia  = map(typeof,axcombs[i])
    outBroad=filter(ax->!in(typeof(ax),by) && !in(typeof(ax),iain),inAxes)
    indims=length(bycubes)==0 ? (totuple(iain),) : (totuple(iain),totuple(ia))
  else
    outBroad=filter(ax->!in(typeof(ax),by),inAxes)
    indims=length(bycubes)==0 ? totuple(ia1) : (totuple(ia1),totuple(CubeAxis[]))
  end
  outBroad=map(typeof,outBroad)
  return mapCube(DATfitOnline,indata,cfun;outtype=(typeof(getGenFun(f,pargs...)(f)),),indims=indims,outdims=(outdims,),outBroadCastAxes=(outBroad,),finalizeOut=(getFinalFun(f,funargs...),),genOut=(getGenFun(f,pargs...),),kwargs...)
end

include("OnlinePCA.jl")

end
