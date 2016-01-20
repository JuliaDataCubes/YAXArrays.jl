module PlotCube
export axVal2Index, plot_ts
using CABLAB, DAT
using Reactive, Interact
using Gadfly
import Patchwork.load_js_runtime
load_js_runtime()
axVal2Index(axis::Union{LonAxis,LatAxis},v)=round(Int,v*axis.values.divisor-axis.values.start)+1
function plot_ts(cube::CubeMem)
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
end
