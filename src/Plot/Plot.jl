module Plot
export plotTS, plotMAP
importall ..Cubes
importall ..CubeAPI
import ..DAT
using Reactive, Interact
using Gadfly
using Images, ImageMagick, Colors
using ..CubeAPI.CachedArrays
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
  signals=Array(Reactive.Signal,0)
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
  p=DAT.getFrontPerm(cube,(axlist[ilon],axlist[ilat]))
  (p[1]==1 && p[2]==2) || (cube=permutedims(cube,p))
  axlist=axes(cube)
  sliders=Any[]
  signals=Reactive.Signal[]
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
      push!(sliceargs,:variab)
      push!(argvars,:variab)
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
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(:(li()=$liftex))
  #display(myfun(cube))
  display(myfun())
end
@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for i=1:nx,j=1:ny]
end
