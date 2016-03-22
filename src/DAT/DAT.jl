module DAT
export @registerDATFunction, joinVars
using ..CubeAPI
using ..CachedArrays
using Base.Dates

getCheckExpr(i::Int,axtype::Symbol)=:(isa(dc.axes[$i],$axtype))
function getCheckExpr(dimsin::Vector)
    ndimin=length(dimsin)
    ex=getCheckExpr(1,dimsin[1])
    for i=2:ndimin
        ex=:($ex || $(getCheckExpr(i,dimsin[i])))
    end
    :($ex || (dc=dims2Front(dc,$(dimsin...))))
end

function getInDimExpr(ndimin)
  quote
    nfrontin=size(dc.data,$(collect(1:ndimin)...))
    nother=div(length(dc.data),prod(nfrontin))
    indata=reshape(dc.data,(nfrontin...,nother))
    inmaskfull=reshape(dc.mask,(nfrontin...,nother))
  end
end

function getOutDimExpr(ndimout,dimsout)
  if ndimout>0
    return quote
      idimout=findOutIndex(dc,$(dimsout.args...))
      nfrontout=size(dc.data,idimout...)
      outdata=zeros(eltype(dc.data),(nfrontout...,nother))
      outmaskfull=zeros(UInt8,(nfrontout...,nother))
    end
 else
   return quote
     nfrontout=()
     idimout=Int[]
     outdata=zeros(eltype(dc.data),nother)
     outmaskfull=zeros(UInt8,nother)
   end
 end
end


abstract DATFunction
const f2Type=Dict{Function,DATFunction}()
const type2f=Dict{DATFunction,Function}()
const fdimsin=Dict{Function,Tuple}()
const fdimsout=Dict{Function,Tuple}()
const fargs=Dict{Function,Tuple}()

totuple(x::AbstractArray)=ntuple(i->x[i],length(x))
function applyDATFunction{T}(fu::Function,cdata::AbstractCubeData{T},addargs...;max_cache=1e6)
  axlist=axes(cdata)
  fT=f2Type[fu]
  indims=collect(fdimsin[fu])
  outdims=collect(fdimsout[fu])
  loopinR=[] #Values to pass to inner Loop
  loopOutR=[] #Values to pass to inner Loop
  inAxes=[]  #Axes to be operated on
  outAxes=[] #Axes to be operated on
  LoopAxes=[] #Axes to loop over
  for a in axlist
    if typeof(a) in fdimsin[fu]
      push!(loopinR,Colon())
      push!(inAxes,a)
    else
      push!(loopinR,length(a))
      push!(LoopAxes,a)
    end
    if typeof(a) in fdimsout[fu]
      push!(outAxes,a)
    end
  end
  axlistOut=[outAxes;LoopAxes]
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
  println("Choosing Cache size of ",loopCacheSize)
  tc=CachedArrays.TempCube(axlistOut,CartesianIndex(totuple([map(length,outAxes);loopCacheSize])))
  j=1
  CacheInSize=Int[]
  for a in axlist
    if typeof(a) in fdimsin[fu]
      push!(CacheInSize,length(a))
    else
      push!(CacheInSize,loopCacheSize[j])
      j=j+1
    end
  end
  @assert j==length(loopCacheSize)+1
  tca=CachedArrays.CachedArray(tc,1,tc.block_size,CachedArrays.MaskedCacheBlock{T,length(axlistOut)});
  cm=CachedArrays.CachedArray(cdata,1,CartesianIndex(totuple(CacheInSize)),CachedArrays.MaskedCacheBlock{T,length(axlist)});
  loopOutR=[fill(Colon(),length(outAxes));map(length,LoopAxes)]
  innerLoop(fT,cm,tca,totuple(loopinR),totuple(loopOutR),addargs)
  CachedArrays.sync(tca)
  tc
end

@generated function innerLoop{T1,T2,T3}(fT::DATFunction,xin,xout,loopinRanges::T1,loopoutRanges::T2,addargs::T3)
    Nin=length(T1.parameters)
    Nout=length(T2.parameters)
    Nloopvars=mapreduce(x->x!=Colon,+,0,T1.parameters)
    NinCol=mapreduce(x->x==Colon,+,0,T1.parameters)
    NoutCol=mapreduce(x->x==Colon,+,0,T2.parameters)
    loopRanges=Expr(:block)
    subIn=Expr(:call,:(CachedArrays.getSubRange),:xin)
    subOut=Expr(:call,:(CachedArrays.getSubRange),:xout)
    j=1
    for i=1:Nin
        if T1.parameters[i]==Colon
            push!(subIn.args,:(:))
        else
            isym=Symbol("i_$(j)")
            unshift!(loopRanges.args,:($isym=1:loopinRanges[$i]))
            push!(subIn.args,isym)
            j+=1
        end
    end
    j=1
    for i=1:Nout
        if T2.parameters[i]==Colon
            push!(subOut.args,:(:))
        else
            isym=Symbol("i_$(j)")
            push!(subOut.args,isym)
            j+=1
        end
    end
    push!(subOut.args,Expr(:kw,:write,true))
    callex=Expr(:call,:f,:ain,:aout,:min,:mout)
    loopBody=quote
        ain,min=$subIn
        aout,mout=$subOut
        fT(ain,aout,min,mout,addargs...)
    end
    Expr(:for,loopRanges,loopBody)
end

macro registerDATFunction(fname, dimsin,dimsout,args...)
    @assert dimsin.head==:tuple
    @assert dimsout.head==:tuple
    tName=esc(gensym())
    sfname=esc(fname)
    quote
        immutable $tName <: DATFunction end
        Base.call(::$tName,xin,xout,maskin,maskout,addargs)=$sfname(xin,xout,maskin,maskout,addargs...)
        Base.call(::$tName,xin,xout,maskin,maskout)=$sfname(xin,xout,maskin,maskout)
        f2Type[$sfname]=$(tName)()
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

"Reshape a cube to bring the wanted dimensions to the front"
function dims2Front{T,N}(dc::CubeMem{T,N},dims...)
  axes=copy(dc.axes)
  perm=Int[i for i=1:length(axes)];
  iold=Int[]
  for i=1:length(dims) push!(iold,findAxis(dims[i],axes)) end
  iold2=sort(iold,rev=true)
  for i=1:length(iold) splice!(perm,iold2[i]) end
  perm=Int[iold;perm]
  newdata=permutedims(dc.data,ntuple(i->perm[i],N))
  newmask=permutedims(dc.mask,ntuple(i->perm[i],N))
  CubeMem(axes[perm],newdata,newmask)
end

findOutIndex(dc::CubeMem,dims...)=Int[findAxis(d,dc.axes) for d in dims]

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

"This function creates a new view of the cube, joining longitude and latitude axes to a single spatial axis"
function mergeLonLat!(c::CubeMem)
ilon=findAxis(LonAxis,c.axes)
ilat=findAxis(LatAxis,c.axes)
ilat==ilon+1 || error("Lon and Lat axes must be consecutive to merge")
lonAx=c.axes[ilon]
latAx=c.axes[ilat]
newVals=Tuple{Float64,Float64}[(lonAx.values[i],latAx.values[j]) for i=1:length(lonAx), j=1:length(latAx)]
newAx=SpatialPointAxis(reshape(newVals,length(lonAx)*length(latAx)));
allNewAx=[c.axes[1:ilon-1];newAx;c.axes[ilat+1:end]];
s  = size(c.data)
s1 = s[1:ilon-1]
s2 = s[ilat+1:end]
newShape=(s1...,length(lonAx)*length(latAx),s2...)
CubeMem(allNewAx,reshape(c.data,newShape),reshape(c.mask,newShape))
end



end
