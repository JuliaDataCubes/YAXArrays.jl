module Plot
export plotTS, plotMAP, plotXY
importall ..Cubes
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
import ..DAT: findAxis,getFrontPerm
import ..Cubes.Axes.axname
import Reactive: Signal
import Interact: slider, dropdown, signal, togglebutton, togglebuttons
import Vega: lineplot, barplot, groupedbar
import Images: Image
import Colors: RGB, @colorant_str, colormap, U8
import ImageMagick
import DataStructures: OrderedDict
import Base.Cartesian: @ntuple,@nexprs

import Patchwork.load_js_runtime
ga=[]
function plotTS{T}(cube::AbstractCubeData{T})
  axlist=axes(cube)
  i=findfirst(a->isa(a,RangeAxis{DateTime}),axlist)
  p=DAT.getFrontPerm(cube,((axlist[i]),))
  p[1]==1 || (cube=permutedims(cube,p))
  axlist=axes(cube)
  sliders=Array(Any,0)
  buttons=Array(Any,0)
  signals=Array(Signal,0)
  argvars=Array(Symbol,0)
  cacheblocksize=Int[]
  ivarax=0
  nvar=0
  ntime=length(axlist[1])
  sliceargs=Any[:(1:$ntime)]
  subcubedims=ones(Int,length(axlist))
  subcubedims[1]=ntime
  for iax=1:length(axlist)
    if isa(axlist[iax],LonAxis)
      push!(sliders,slider(axlist[iax].values,label="Longitude"))
      push!(signals,signal(sliders[end]))
      push!(sliceargs,:(axVal2Index(axlist[$iax],lon)))
      push!(argvars,:lon)
      #display(sliders[end])
    elseif isa(axlist[iax],LatAxis)
      push!(sliders,slider(reverse(axlist[iax].values),label="Latitude"))
      push!(signals,signal(sliders[end]))
      push!(sliceargs,:(axVal2Index(axlist[$iax],lat)))
      push!(argvars,:lat)
      #display(sliders[end])
    elseif isa(axlist[iax],SpatialPointAxis)
      push!(sliders,slider(1:length(axlist[iax]),label="Point"))
      push!(signals,signal(sliders[end]))
      push!(sliceargs,:point)
      push!(argvars,:point)
    elseif isa(axlist[iax],CategoricalAxis)
      ivarax=iax
      push!(sliceargs,:(error()))
      nvar=length(axlist[iax])
      varButtons=map(x->togglebutton(x,value=true),axlist[iax].values)
      push!(argvars,map(x->symbol(string("s_",x)),1:length(axlist[iax]))...)
      push!(buttons,varButtons...)
      push!(signals,map(signal,varButtons)...)
    end
  end
  plotfun=Expr(:call,:plot,Expr(:...,:lay),:(Scale.color_discrete()))
  plotfun2=quote
    lay=Array(Any,0)
    axlist=axes(cube)
  end
  #Generate CachedArray for plotting
  ca=getMemHandle(cube,20,CartesianIndex(ntuple(i->subcubedims[i],length(subcubedims))))
  push!(ga,ca)
  lga=length(ga)

  layerex=Array(Any,0)
  if nvar==0
    dataslice=Expr(:call,:getSubRange,:(ga[$lga]),sliceargs...)
    push!(plotfun2.args,:(push!(lay,layer(x=axlist[1].values,y=$(dataslice)[1],Geom.line))))
  else
    for ivar=1:nvar
      sliceargs[ivarax]=ivar
      dataslice=Expr(:call,:getSubRange,:(ga[$lga]),sliceargs...)
      push!(layerex,:(layer(x=axlist[1].values,y=@sync($(dataslice)[1]),Geom.line,color=fill($(axlist[ivarax].values[ivar]),$ntime))))
    end
  end
  for i=1:nvar push!(plotfun2.args,:($(symbol(string("s_",i))) && push!(lay,$(layerex[i])))) end
  push!(plotfun2.args,plotfun)
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
    myfun=eval(:(li(cube)=$liftex))
    for b in buttons display(b) end
    for s in sliders display(s) end
    display(myfun(cube))
end

toYr(tx::TimeAxis)=((tx.values.startyear+(tx.values.startst-1)/tx.values.NPY):(1.0/tx.values.NPY):(tx.values.stopyear+(tx.values.stopst-1)/tx.values.NPY))-(tx.values.startyear+(tx.values.startst-1)/tx.values.NPY)

r1(x)=reshape(x,length(x))
prepAx(x)=x.values
prepAx(x::TimeAxis)=toYr(x)
function repAx(x,idim,ax)
  l=length(x)
    inrep=prod(size(x)[1:idim-1])
  outrep=div(l,(inrep*size(x,idim)))
    repeat(collect(ax),inner=[inrep],outer=[outrep])
end
function count_to(f,c,i)
    ni=0
    for ind=1:i
        f(c[ind]) && (ni+=1)
    end
    return ni
end

getWidget(x::CategoricalAxis)=dropdown(Dict(zip(x.values,1:length(x.values))),label=axname(x))
getWidget{T<:Real}(x::RangeAxis{T})=step(x.values) > 0 ? slider(x.values,label=axname(x)) : slider(reverse(x.values),label=axname(x))
getWidget(x::RangeAxis)=slider(1:length(x),label=axname(x))



function plotXY{T}(cube::AbstractCubeData{T};group=0,xaxis=-1,kwargs...)
  axlist=axes(cube)
  axlabels=map(axname,axlist)
  fixedvarsEx=quote end
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  if xaxis!=-1
    ixaxis=findAxis(xaxis,axlist)
    if ixaxis>0
      push!(fixedvarsEx.args,:(ixaxis=$ixaxis))
      push!(fixedAxes,axlist[ixaxis])
    else
      ixaxis=0
    end
  else
    ixaxis=0
  end
  if group!=0
    igroup=findAxis(group,axlist)
    igroup>0 || error("Axis $group not found!")
    push!(fixedvarsEx.args,:(igroup=$igroup))
    push!(fixedAxes,axlist[igroup])
  else
    igroup=0
  end
  for (sy,val) in kwargs
    ivalaxis=findAxis(string(sy),axlist)
    ivalaxis>0 || error("Axis $sy not found")
    s=Symbol("v_$ivalaxis")
    push!(fixedvarsEx.args,:($s=$val))
    push!(fixedAxes,axlist[ivalaxis])
  end

  availableIndices=find(ax->!in(ax,fixedAxes),axlist)
  availableAxis=axlist[availableIndices]


  if length(availableAxis) > 0
    if ixaxis==0
      xaxmenu=dropdown(OrderedDict(zip(axlabels[availableIndices],availableIndices)),label="X Axis",value=availableIndices[1],value_label=axlabels[availableIndices[1]])
      xax=signal(xaxmenu)
      push!(widgets,xaxmenu)
      push!(argvars,:ixaxis)
      push!(signals,xax)
    end
    if igroup==0
      groupmenu=dropdown(OrderedDict(zip(["None";axlabels[availableIndices]],[0;availableIndices])),label="X Axis",value=0,value_label="None")
      groupsig=signal(groupmenu)
      push!(widgets,groupmenu)
      push!(argvars,:igroup)
      push!(signals,groupsig)
    end
    for i in availableIndices
      w=getWidget(axlist[i])
      push!(widgets,w)
      push!(signals,signal(w))
      push!(argvars,Symbol(string("v_",i)))
    end
  end
  nax=length(axlist)

  plotfun2=quote
    axlist=axes(cube)
    $fixedvarsEx
    ndim=length(axlist)
    subcubedims=@ntuple $nax d->(d==ixaxis || d==igroup) ? length(axlist[d]) : 1
    sliceargs=@ntuple $nax d->(d==ixaxis || d==igroup) ? (1:length(axlist[d])) : axVal2Index(axlist[d],v_d)
    println(sliceargs)
    ca = getMemHandle(cube,1,CartesianIndex(subcubedims))
    dataslice=getSubRange(ca,sliceargs...)[1]
    jxaxis=count_to(x->isa(x,Range),sliceargs,ixaxis)

    xvals = repAx(dataslice,jxaxis,prepAx(axlist[ixaxis]))
    yvals = r1(dataslice)

    if igroup > 0
        plotf = isa(axlist[ixaxis],CategoricalAxis) ? groupedbar : lineplot
        jgroup=count_to(x->isa(x,Range),sliceargs,igroup)
        gvals=repAx(dataslice,jgroup,prepAx(axlist[igroup]))
        p=plotf(x=xvals,y=yvals,group=gvals)
    else
        plotf = isa(axlist[ixaxis],CategoricalAxis) ? barplot : lineplot
        p=plotf(x=xvals,y=yvals)
    end
    p
  end
  if length(argvars)==0
    x=eval(:(cube->$plotfun2))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(:(li(cube)=$liftex))
  for w in widgets display(w) end
  display(myfun(cube))
end



function getMemHandle{T}(cube::AbstractCubeData{T},nblock,block_size)
  CachedArray(cube,nblock,block_size,CachedArrays.MaskedCacheBlock{T,length(block_size)})
end
getMemHandle(cube::AbstractCubeMem,nblock,block_size)=cube

function getMinMax(x,mask)
  mi=typemax(eltype(x))
  ma=typemin(eltype(x))
  for ix in eachindex(x)
        if mask[ix]==VALID
      if x[ix]<mi mi=x[ix] end
      if x[ix]>ma ma=x[ix] end
    end
  end
  if mi==typemax(eltype(x)) || ma==typemin(eltype(x))
    mi,ma=(zero(eltype(x)),one(eltype(x)))
  elseif mi==ma
    mi,ma=(mi,mi+eps(mi))
  end
  mi,ma
end

function val2col(x,m,colorm,mi,ma,misscol,oceancol)
  N=length(colorm)
  if !isnan(x) && m==VALID || m==FILLED
    i=min(N,max(1,ceil(Int,(x-mi)/(ma-mi)*N)))
    return colorm[i]
  elseif (m & OCEAN)==OCEAN
    return oceancol
  else
    return misscol
  end
end

function plotMAP{T}(cube::CubeAPI.AbstractCubeData{T};dmin::T=zero(T),dmax::T=zero(T))
  axlist=axes(cube)
  ilon=findfirst(a->isa(a,LonAxis),axlist)
  ilat=findfirst(a->isa(a,LatAxis),axlist)
  p=getFrontPerm(cube,(axlist[ilon],axlist[ilat]))
  (p[1]==1 && p[2]==2) || (cube=permutedims(cube,p))
  axlist=axes(cube)
  sliders=Any[]
  signals=Signal[]
  argvars=Symbol[]
  ivarax=0
  nvar=0
  nlon=length(axlist[1])
  nlat=length(axlist[2])
  subcubedims=ones(Int,length(axlist))
  subcubedims[1]=nlon
  subcubedims[2]=nlat
  sliceargs=Any[:(1:$nlon),:(1:$nlat)]
  for iax=3:length(axlist)
    if isa(axlist[iax],RangeAxis)
      push!(sliders,slider(1:length(axlist[iax].values),label="Time Step"))
      push!(signals,signal(sliders[end]))
      push!(sliceargs,:time)
      push!(argvars,:time)
      display(sliders[end])
    elseif isa(axlist[iax],CategoricalAxis)
      ivarax=iax
      push!(sliceargs,symbol(Cubes.Axes.axname(axlist[iax])))
      push!(argvars,symbol(Cubes.Axes.axname(axlist[iax])))
      nvar=length(axlist[iax])
      varButtons=togglebuttons([(axlist[iax].values[i],i) for i=1:length(axlist[iax].values)])
      push!(sliders,varButtons)
      push!(signals,signal(varButtons))
      display(varButtons)
    end
  end
  push!(ga,getMemHandle(cube,1,CartesianIndex(ntuple(i->subcubedims[i],length(axlist)))))
  lga=length(ga)
  dataslice=Expr(:call,:getSubRange,:(ga[$lga]),sliceargs...)
  mimaex = dmin==dmax ? :((mi,ma)=getMinMax(a,m)) : :(mi=$(dmin);ma=$(dmax))
  plotfun=quote
    a,m=$dataslice
    nx,ny=size(a)
    $mimaex
    colorm=colormap("oranges")
    oceancol=colorant"darkblue"
    misscol=colorant"gray"
    rgbar=getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)
    Image(rgbar,Dict("spatialorder"=>["x","y"]))
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun)
  if length(argvars)==0
    x=eval(lambda)
    return x()
  end
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(:(li()=$liftex))
  display(myfun())
end
@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for i=1:nx,j=1:ny]
end
