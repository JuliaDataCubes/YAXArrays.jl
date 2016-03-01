module Plot
export axVal2Index, plotTS, plotMAP
using ..DAT
using ..CubeAPI
using Reactive, Interact
using Gadfly
using Images, ImageMagick, Colors
using ..CachedArrays
import Patchwork.load_js_runtime
ga=Array(CachedArray,1)
axVal2Index(axis::Union{LonAxis,LatAxis},v)=round(Int,v*axis.values.divisor-axis.values.start)+1
function plotTS{T}(cube::AbstractCubeData{T})
    sliders=Array(Any,0)
    buttons=Array(Any,0)
    signals=Array(Reactive.Signal,0)
    sliceargs=Array(Any,0)
    argvars=Array(Symbol,0)
    cacheblocksize=Int[]
    xaxi=0
    ivarax=0
    nvar=0
    ntime=0
    axlist=axes(cube)
    subcubedims=ones(Int,length(axlist))
    for iax=1:length(axlist)
        if isa(axlist[iax],LonAxis)
            push!(sliders,slider(axlist[iax].values,label="Longitude"))
            push!(signals,signal(sliders[end]))
            push!(sliceargs,:(axVal2Index(axlist[$iax],lon)))
            push!(argvars,:lon)
            #display(sliders[end])
        elseif isa(axlist[iax],LatAxis)
            push!(sliders,slider(axlist[iax].values,label="Latitude"))
            push!(signals,signal(sliders[end]))
            push!(sliceargs,:(axVal2Index(axlist[$iax],lat)))
            push!(argvars,:lat)
            #display(sliders[end])
        elseif isa(axlist[iax],TimeAxis)
            ntime=length(axlist[iax])
            push!(sliceargs,:(1:$ntime))
            xaxi=iax
            subcubedims[iax]=ntime
        elseif isa(axlist[iax],VariableAxis)
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
    ga[1] = CachedArray(cube,50,CartesianIndex(ntuple(i->subcubedims[i],length(subcubedims))),CachedArrays.MaskedCacheBlock{T,length(subcubedims)})

    layerex=Array(Any,0)
    if nvar==0
        dataslice=Expr(:call,:getSubRange,:(ga[1]),sliceargs...)
        push!(plotfun2.args,:(push!(lay,layer(x=axlist[$xaxi].values,y=$(dataslice)[1],Geom.line))))
    else
        for ivar=1:nvar
            sliceargs[ivarax]=ivar
            dataslice=Expr(:call,:getSubRange,:(ga[1]),sliceargs...)
            push!(layerex,:(layer(x=axlist[$xaxi].values,y=@sync($(dataslice)[1]),Geom.line,color=fill($(axlist[ivarax].values[ivar]),length(axlist[$xaxi])))))
        end
    end
    for i=1:nvar push!(plotfun2.args,:($(symbol(string("s_",i))) && push!(lay,$(layerex[i])))) end
    push!(plotfun2.args,plotfun)
    lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
    liftex = Expr(:call,:map,lambda,signals...)
    myfun=eval(:(li(cube)=$liftex))
    for b in buttons display(b) end
    display(myfun(cube))
    for s in sliders display(s) end
    nothing
    #liftex2
end



function getMinMax(x,mask)
  mi=typemax(eltype(x))
  ma=typemin(eltype(x))
  for ix in eachindex(x)
    if mask[ix]==VALID
      if x[ix]<mi mi=x[ix] end
      if x[ix]>ma ma=x[ix] end
    end
  end
  mi,ma
end

function val2col(x,m,colorm,mi,ma,misscol,oceancol)
  N=length(colorm)
  if m==VALID
    i=min(N,max(1,ceil(Int,(x-mi)/(ma-mi)*N)))
    return colorm[i]
  elseif (m & OCEAN)==OCEAN
    return oceancol
  else
    return misscol
  end
end

function plotMAP{T}(cube::AbstractCubeData{T};dmin::T=zero(T),dmax::T=zero(T))
    sliders=Any[]
    signals=Reactive.Signal[]
    sliceargs=Any[]
    argvars=Symbol[]
    lonaxi=0
    lataxi=0
    ivarax=0
    nvar=0
    nlon=0
    nlat=0
    axlist=axes(cube)
    subcubedims=ones(Int,length(axlist))
    for iax=1:length(axlist)
        if isa(axlist[iax],LonAxis)
          lonaxi=iax
          nlon = length(axlist[iax])
          subcubedims[iax]=nlon
          push!(sliceargs,:(1:$(nlon)))
      elseif isa(axlist[iax],LatAxis)
          lataxi=iax
          nlat = length(axlist[iax])
          subcubedims[iax]=nlat
          push!(sliceargs,:(1:$nlat))
      elseif isa(axlist[iax],TimeAxis)
          push!(sliders,slider(1:length(axlist[iax].values),label="Time Step"))
          push!(signals,signal(sliders[end]))
          push!(sliceargs,:time)
          push!(argvars,:time)
          display(sliders[end])
      elseif isa(axlist[iax],VariableAxis)
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
    ga[1] = CachedArray(cube,5,CartesianIndex(ntuple(i->subcubedims[i],length(axlist))),CachedArrays.MaskedCacheBlock{T,length(axlist)})
    dataslice=Expr(:call,:getSubRange,:(ga[1]),sliceargs...)
    mimaex = dmin==dmax ? :((mi,ma)=getMinMax(a,m)) : :(mi=$(dmin);ma=$(dmax))
    plotfun=quote
      a,m=$dataslice
      nx,ny=size(a)
      $mimaex
      colorm=colormap("oranges")
      oceancol=colorant"blue"
      misscol=colorant"gray"
      rgbar=getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)
      Image(rgbar,Dict("spatialorder"=>["x","y"]))
    end
    lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun)
    liftex = Expr(:call,:map,lambda,signals...)
    myfun=eval(:(li(cube)=$liftex))
    display(myfun(cube))
    #plotfun
end
@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for i=1:nx,j=1:ny]
end
