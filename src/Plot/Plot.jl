module Plot
export axVal2Index, plotTS, plotMAP
using ..DAT
using ..CubeAPI
using Reactive, Interact
using Gadfly
using Images, ImageMagick, Colors
import Patchwork.load_js_runtime
load_js_runtime()
axVal2Index(axis::Union{LonAxis,LatAxis},v)=round(Int,v*axis.values.divisor-axis.values.start)+1
function plotTS(cube::CubeMem)
    sliders=Array(Any,0)
    signals=Array(Reactive.Input,0)
    sliceargs=Array(Any,0)
    argvars=Array(Symbol,0)
    xaxi=0
    ivarax=0
    nvar=0
    for iax=1:length(cube.axes)
        if isa(cube.axes[iax],LonAxis)
            push!(sliders,slider(cube.axes[iax].values,label="Longitude"))
            push!(signals,signal(sliders[end]))
            push!(sliceargs,:(axVal2Index(cube.axes[$iax],lon)))
            push!(argvars,:lon)
            display(sliders[end])
        elseif isa(cube.axes[iax],LatAxis)
            push!(sliders,slider(cube.axes[iax].values,label="Latitude"))
            push!(signals,signal(sliders[end]))
            push!(sliceargs,:(axVal2Index(cube.axes[$iax],lat)))
            push!(argvars,:lat)
            display(sliders[end])
        elseif isa(cube.axes[iax],TimeAxis)
            push!(sliceargs,:(:))
            xaxi=iax
        elseif isa(cube.axes[iax],VariableAxis)
            ivarax=iax
            push!(sliceargs,:(error()))
            nvar=length(cube.axes[iax])
            varButtons=map(x->togglebutton(x,value=true),cube.axes[iax].values)
            push!(argvars,map(x->symbol(string("s_",x)),1:length(cube.axes[iax]))...)
            push!(sliders,varButtons...)
            push!(signals,map(signal,varButtons)...)
            for vB in varButtons display(vB) end
        end
    end
    plotfun=Expr(:call,:plot,Expr(:...,:lay),:(Scale.color_discrete()))
    plotfun2=quote lay=Array(Any,0) end

    layerex=Array(Any,0)
    if nvar==0
        dataslice=Expr(:call,:slice,:(cube.data),sliceargs...)
        push!(plotfun2.args,:(push!(lay,layer(x=cube.axes[$xaxi].values,y=$dataslice,Geom.line))))
    else
        for ivar=1:nvar
            sliceargs[ivarax]=ivar
            dataslice=Expr(:call,:slice,:(cube.data),sliceargs...)
            push!(layerex,:(layer(x=cube.axes[$xaxi].values,y=$dataslice,Geom.line,color=fill($(cube.axes[ivarax].values[ivar]),length(cube.axes[$xaxi])))))
        end
    end
    for i=1:nvar push!(plotfun2.args,:($(symbol(string("s_",i))) && push!(lay,$(layerex[i])))) end
    push!(plotfun2.args,plotfun)
    lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
    liftex = Expr(:call,:lift,lambda,signals...)
    myfun=eval(:(li(cube)=$liftex))
    myfun(cube)
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

function val2col(x,m,colorm,mi,ma,misscol)
  N=length(colorm)
  if m==VALID
    i=min(N,max(1,ceil(Int,(x-mi)/(ma-mi)*N)))
    return colorm[i]
  else
    return misscol
  end
end

function plotMAP(cube::CubeMem)
    sliders=Array(Any,0)
    signals=Array(Reactive.Input,0)
    sliceargs=Array(Any,0)
    argvars=Array(Symbol,0)
    lonaxi=0
    lataxi=0
    ivarax=0
    nvar=0
    for iax=1:length(cube.axes)
        if isa(cube.axes[iax],LonAxis)
          lonaxi=iax
          push!(sliceargs,:(:))
        elseif isa(cube.axes[iax],LatAxis)
          lataxi=iax
          push!(sliceargs,:(:))
        elseif isa(cube.axes[iax],TimeAxis)
          push!(sliders,slider(1:length(cube.axes[iax].values),label="Time Step"))
          push!(signals,signal(sliders[end]))
          push!(sliceargs,:time)
          push!(argvars,:time)
          display(sliders[end])
        elseif isa(cube.axes[iax],VariableAxis)
          ivarax=iax
          push!(sliceargs,:variab)
          push!(argvars,:variab)
          nvar=length(cube.axes[iax])
          varButtons=togglebuttons([(cube.axes[iax].values[i],i) for i=1:length(cube.axes[iax].values)])
          push!(sliders,varButtons)
          push!(signals,signal(varButtons))
          display(varButtons)
        end
    end
    dataslice=Expr(:call,:slice,:(cube.data),sliceargs...)
    maskslice=Expr(:call,:slice,:(cube.mask),sliceargs...)
    plotfun=quote
      a=$dataslice
      m=$maskslice
      nx,ny=size(a)
      mi,ma=getMinMax(a,m)
      colorm=colormap("blues")
      misscol=colorant"black"
      rgbar=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol) for i=1:nx,j=1:ny]
      Image(rgbar,Dict("spatialorder"=>["x","y"]))
    end
    lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun)
    liftex = Expr(:call,:lift,lambda,signals...)
    myfun=eval(:(li(cube)=$liftex))
    myfun(cube)
    #plotfun
end
end
