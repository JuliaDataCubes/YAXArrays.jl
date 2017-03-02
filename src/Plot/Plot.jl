module Plot
export plotTS, plotMAP, plotXY, plotScatter, plotMAPRGB
importall ..Cubes
importall ..CubeAPI
importall ..CubeAPI.Mask
importall ..CubeAPI.CachedArrays
import ..DAT
import ..DAT: findAxis,getFrontPerm
import ..Cubes.Axes.axname
import Reactive: Signal
import Interact: slider, dropdown, signal, togglebutton, togglebuttons
import Vega: lineplot, barplot, groupedbar, scatterplot, xlab!, ylab!
import Colors: RGB, @colorant_str, colormap,  distinguishable_colors
import FixedPointNumbers: Normed
import Base.Cartesian: @ntuple,@nexprs
import Patchwork.load_js_runtime
import Measures
import Compose
import Images
import DataStructures: OrderedDict
import Suppressor: @suppress

typealias U8 Normed{UInt8,8}
#import Patchwork.load_js_runtime


abstract CABLABPlots

include("maps.jl")


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

getWidget(x::CategoricalAxis;label=axname(x))       = dropdown(Dict(zip(x.values,1:length(x.values))),label=label)
getWidget{T<:Real}(x::RangeAxis{T};label=axname(x)) = step(x.values) > 0 ? slider(x.values,label=label) : slider(reverse(x.values),label=label)
getWidget(x::RangeAxis;label=axname(x))             = slider(1:length(x),label=label)
getWidget(x::SpatialPointAxis;label="Spatial Point")= slider(1:length(x),label=label)

plotTS(x;kwargs...)=plotXY(x,xaxis=TimeAxis;kwargs...)

setPlotAxis(x::Void,axlist,name,fixedvarsEx,fixedAxes)=0
function setPlotAxis(x,name,axlist,fixedvarsEx,fixedAxes)
  ix=findAxis(x,axlist)
  if ix>0
    push!(fixedvarsEx.args,:($name=$ix))
    push!(fixedAxes,axlist[ix])
    return ix
  else
    return 0
  end
end

function createWidgets(axlist,availableAxis,availableIndices,fixedvarsEx,axlabels,widgets,signals,argvars,axtuples)

  if !isempty(availableAxis)
    for (ix,ixs,label,musthave) in axtuples
      if ix == 0
        options = collect(musthave ? zip(axlabels[availableIndices],availableIndices) : zip(["None";axlabels[availableIndices]],[0;availableIndices]))
        println(options)
        axmenu  = dropdown(OrderedDict(options),label=label,value=options[1][2],value_label=options[1][1])
        sax=signal(axmenu)
        push!(widgets,axmenu)
        push!(argvars,ixs)
        push!(signals,sax)
      end
    end
    for i in availableIndices
      w=getWidget(axlist[i])
      push!(widgets,w)
      push!(signals,signal(w))
      push!(argvars,Symbol(string("v_",i)))
    end
  else
    for (ix,ixs,label,musthave) in axtuples
      if ix==0
        musthave && error("No axis left to put on $label")
        push!(fixedvarsEx.args,:($ixs=0))
      end
    end
  end
end

import Plots
import StatPlots

"""
`plotXY(cube::AbstractCubeData; group=0, xaxis=-1, kwargs...)`

Generic plotting tool for cube objects, can be called on any type of cube data.

### Keyword arguments

* `xaxis` which axis is to be used as x axis. Can be either an axis Datatype or a string. Short versions of axes names are possible as long as the axis can be uniquely determined.
* `group` it is possible to group the plot by a categorical axis. Can be either an axis data type or a string.
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the x axis or group variable and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotXY{T}(cube::AbstractCubeData{T};group=nothing,xaxis=nothing,kwargs...)

  axlist=axes(cube)
  axlabels=map(axname,axlist)
  fixedvarsEx=quote end
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  ixaxis = setPlotAxis(xaxis,:ixaxis,axlist,fixedvarsEx,fixedAxes)
  igroup = setPlotAxis(group,:igroup,axlist,fixedvarsEx,fixedAxes)
  for (sy,val) in kwargs
    setPlotAxis(string(sy),Symbol("v_$i"),axlist,fixedvarsEx,fixedAxes)
  end

  availableIndices=find(ax->!in(ax,fixedAxes),axlist)
  availableAxis=axlist[availableIndices]

  createWidgets(axlist,availableAxis,availableIndices,fixedvarsEx,axlabels,widgets,signals,argvars,[(ixaxis,:ixaxis,"X Axis",true),(igroup, :igroup, "Group",false)])

  nax=length(axlist)

  plotfun2=quote
    axlist=axes(cube)

    $fixedvarsEx
    ndim=length(axlist)
    subcubedims=@ntuple $nax d->(d==ixaxis || d==igroup) ? length(axlist[d]) : 1

    a           = zeros(eltype(cube), subcubedims)
    m           = zeros(UInt8,        subcubedims)
    indstart    = @ntuple $nax d->(d==ixaxis || d==igroup) ? 1 : axVal2Index(axlist[d],v_d,fuzzy=true)
    indend      = @ntuple $nax d->(d==ixaxis || d==igroup) ? subcubedims[d] : axVal2Index(axlist[d],v_d,fuzzy=true)
    _read(cube,(a,m),CartesianRange(CartesianIndex(indstart),CartesianIndex(indend)))

    sd2 = filter(i->i>1,subcubedims)
    a,m = reshape(a,sd2...),reshape(m,sd2...)

    if igroup > 0
      plotf = isa(axlist[ixaxis],CategoricalAxis) ? StatPlots.groupedbar : Plots.plot
      p=plotf(axlist[ixaxis].values,a,lab=reshape(string.(axlist[igroup].values),(1,length(axlist[igroup]))))
    else
      plotf = isa(axlist[ixaxis],CategoricalAxis) ? Plots.bar : Plots.plot
      p=plotf(axlist[ixaxis].values,a)
    end
    p
  end
  if length(argvars)==0
    x=eval(:(cube->$plotfun2))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
  #println(liftex)
  myfun=eval(
  quote
    local li
    li(cube)=$liftex
  end
  )
  for w in widgets display(w) end
  display(myfun(cube))
end


import PlotUtils.optimize_ticks
import PlotUtils.cgrad
import Colors.@colorant_str
import Compose: rectangle, text, line, compose, context, stroke, svgattribute, bitmap, HCenter, VBottom, HRight, VCenter
const namedcolms=Dict(
:viridis=>[cgrad(:viridis)[ix] for ix in linspace(0,1,100)],
:magma=>[cgrad(:magma)[ix] for ix in linspace(0,1,100)],
:inferno=>[cgrad(:inferno)[ix] for ix in linspace(0,1,100)],
:plasma=>[cgrad(:plasma)[ix] for ix in linspace(0,1,100)])
typed_dminmax{T<:Integer}(::Type{T},dmin,dmax)=(Int(dmin),Int(dmax))
typed_dminmax{T<:AbstractFloat}(::Type{T},dmin,dmax)=(Float64(dmin),Float64(dmax))
typed_dminmax2{T<:Integer}(::Type{T},dmin,dmax)=(isa(dmin,Tuple) ? (Int(dmin[1]),Int(dmin[2]),Int(dmin[3])) : (Int(dmin),Int(dmin),Int(dmin)), isa(dmax,Tuple) ? (Int(dmax[1]),Int(dmax[2]),Int(dmax[3])) : (Int(dmax),Int(dmax),Int(dmax)))
typed_dminmax2{T<:AbstractFloat}(::Type{T},dmin,dmax)=(isa(dmin,Tuple) ? (Float64(dmin[1]),Float64(dmin[2]),Float64(dmin[3])) : (Float64(dmin),Float64(dmin),Float64(dmin)), isa(dmax,Tuple) ? (Float64(dmax[1]),Float64(dmax[2]),Float64(dmax[3])) : (Float64(dmax),Float64(dmax),Float64(dmax)))




function plotGeneric{T}(plotObj::CABLABPlots, cube::CubeAPI.AbstractCubeData{T};kwargs...)


  axlist=axes(cube)

  fixedvarsEx=getFixedVars(plotObj,cube)

  axlist=axes(cube)
  axlabels=map(axname,axlist)
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  pAxVars=plotAxVars(plotObj)

  ifixed = map(t->setPlotAxis(t[1],t[2],axlist,fixedvarsEx,fixedAxes),pAxVars)

  for (sy,val) in kwargs
    setPlotAxis(string(sy),Symbol("v_$i"),axlist,fixedvarsEx,fixedAxes)
  end

  availableIndices=find(ax->!in(ax,fixedAxes),axlist)
  availableAxis=axlist[availableIndices]

  createWidgets(axlist,availableAxis,availableIndices,fixedvarsEx,axlabels,widgets,signals,argvars,map((i,j)->(i,j...),ifixed,pAxVars))

  nax        = length(axlist)
  nCubes     = nplotCubes(plotObj)

  plotfun=quote
    axlist=axes(cube)
    $fixedvarsEx
    ndim=$nax

    subcubedims = @ntuple $nax d->$(makeifs(match_subCubeDims(plotObj).args))
    sd2 = filter(i->i>1,subcubedims)

    @nexprs $nCubes f->begin
      a_f        = zeros(eltype(cube), subcubedims)
      m_f        = zeros(UInt8,        subcubedims)
      indstart_f = @ntuple $nax d->$(makeifs(match_indstart(plotObj).args))
      indend_f   = @ntuple $nax d->$(makeifs(match_indend(plotObj).args))
      _read(cube,(a_f,m_f),CartesianRange(CartesianIndex(indstart_f),CartesianIndex(indend_f)))
      a_f,m_f = reshape(a_f,sd2...),reshape(m_f,sd2...)
    end

    $(getafterEx(plotObj))
    $(plotCall(plotObj))
  end
  if length(argvars)==0
    x=eval(:(cube->$plotfun))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun)
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(quote
  local li
  li(cube)=$liftex
end)
foreach(display,widgets)
display(myfun(cube))
end



import Showoff.showoff
function getlegend(xmin,xmax,colm,legheight)
  xoffs=0.05
  xl=1-2xoffs
  tlabs,smin,smax=optimize_ticks(Float64(xmin),Float64(xmax),extend_ticks=false,k_min=4)
  tpos=[(tlabs[i]-xmin)/(xmax-xmin) for i=1:length(tlabs)]
  r=rectangle([(i-1)/length(colm) for i in 1:length(colm)],[0],[1/(length(colm)-1)],[1])
  f=fill([colm[div((i-1)*length(colm),length(colm))+1] for i=1:length(colm)])
  bar=compose(context(xoffs,0.35,xl,0.55),r,f,stroke(nothing),svgattribute("shape-rendering","crispEdges"))
  tlabels=compose(context(xoffs,0,xl,0.2),text(tpos,[1],showoff(tlabs),[HCenter()],[VBottom()]))
  dlines=compose(context(xoffs,0.25,xl,0.1),line([[(tpx,0.1),(tpx,0.9)] for tpx in tpos]),stroke(colorant"black"))
  compose(context(0,1Measures.h-legheight,1,legheight),bar,tlabels,dlines)
end

function getlegend(colm,width)
  texth1=Compose.max_text_extents(Compose.default_font_family, Compose.default_font_size, first(keys(colm)))[2]
  texth=texth1*1.05*length(colm)
  yoffs=(Measures.h-texth)/2
  yl=texth
  ncol=length(colm)
  tpos=[(i-0.5)/ncol for i=1:ncol]
  r=Compose.circle([0.5],[(i-0.5)/ncol for i in 1:ncol],[max(1/(ncol-1),0.5)])
  f=fill(collect(values(colm)))
  bar=compose(context(0.9,yoffs,0.1,yl),r,f,stroke(nothing),svgattribute("shape-rendering","crispEdges"))
  tlabels=compose(context(0,yoffs,0.85,yl),Compose.text([1],tpos,collect(keys(colm)),[HRight()],[VCenter()]))
  compose(context(1Measures.w-width,0,width,1),bar,tlabels)
end


"""
`plotScatter(cube::AbstractCubeData; vsaxis=VariableAxis, alongaxis=0, group=0, xaxis=0, yaxis=0, kwargs...)`

Generic plotting tool for cube objects to generate scatter plots, like variable `A` against variable `B`. Can be called on any type of cube data.

### Keyword arguments

* `vsaxis` determines the axis from which the x and y variables are drawn.
* `alongaxis` determines the axis along which the variables are plotted. E.g. if you choose `TimeAxis`, a dot will be plotted for each time step.
* `xaxis` index or value of the variable to plot on the x axis
* `yaxis` index or value of the variable to plot on the y axis
* `group` it is possible to group the plot by an axis. Can be either an axis data type or a string. *Caution: This will increase the number of plotted data points*
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the `vsaxis` or `alongaxis` or `group` and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotScatter{T}(cube::AbstractCubeData{T};group=0,vsaxis=VariableAxis,xaxis=0,yaxis=0,alongaxis=0,kwargs...)

  axlist=axes(cube)
  axlabels=map(axname,axlist)
  fixedvarsEx=quote end
  widgets=Any[]
  argvars=Symbol[]
  fixedAxes=CubeAxis[]
  signals=Signal[]

  ivsaxis=findAxis(vsaxis,axlist)
  if ivsaxis>0
    push!(fixedvarsEx.args,:(ivsaxis=$ivsaxis))
    push!(fixedAxes,axlist[ivsaxis])
    vsaxis = axlist[ivsaxis]
  else
    throw(ArgumentError("Could not find axis $vsaxis in data cube."))
  end
  if length(vsaxis)<2
    error("Scatterplot not possible because $(vsaxis) has only one element.")
  elseif length(vsaxis)==2
    ixaxis=1
    iyaxis=2
    push!(fixedvarsEx.args,:(xval=1))
    push!(fixedvarsEx.args,:(yval=2))
    xfixed=true
    yfixed=true
  else
    if xaxis!=0
      ixaxis=axVal2Index(vsaxis,xaxis,fuzzy=true)
      push!(fixedvarsEx.args,:(xval=$ixaxis))
      1<=ixaxis<=length(vsaxis) || error("invalid value for x axis chosen")
    else
      ixaxis=0
    end
    if yaxis!=0
      iyaxis=axVal2Index(vsaxis,yaxis,fuzzy=true)
      push!(fixedvarsEx.args,:(yval=$iyaxis))
      1<=iyaxis<=length(vsaxis) || error("invalid value for y axis chosen")
    else
      iyaxis=0
    end
  end
  if alongaxis!=0
    ialongaxis=findAxis(alongaxis,axlist)
    ialongaxis>0 || error("Axis $alongaxis not found!")
    push!(fixedvarsEx.args,:(ialongaxis=$ialongaxis))
    push!(fixedAxes,axlist[ialongaxis])
  else
    ialongaxis=0
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

  if ixaxis==0
    w=getWidget(vsaxis,label="X Axis")
    push!(widgets,w)
    push!(signals,signal(w))
    push!(argvars,:xval)
  end
  if iyaxis==0
    w=getWidget(vsaxis,label="Y Axis")
    push!(widgets,w)
    push!(signals,signal(w))
    push!(argvars,:yval)
  end

  if length(availableAxis) > 0

    if ialongaxis==0
      alongmenu=dropdown(OrderedDict(zip(axlabels[availableIndices],availableIndices)),label="Scatter along",value=availableIndices[1],value_label=axlabels[availableIndices[1]])
      alongsig=signal(alongmenu)
      push!(widgets,alongmenu)
      push!(argvars,:ialongaxis)
      push!(signals,alongsig)
    end
    if igroup==0
      groupmenu=dropdown(OrderedDict(zip(["None";axlabels[availableIndices]],[0;availableIndices])),label="Group",value=0,value_label="None")
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
    subcubedims = @ntuple $nax d->(d==ialongaxis || d==igroup) ? length(axlist[d]) : 1
    sliceargsx  = @ntuple $nax d->(d==ialongaxis || d==igroup) ? (1:length(axlist[d])) : (d==ivsaxis) ? axVal2Index(axlist[d],xval,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    sliceargsy  = @ntuple $nax d->(d==ialongaxis || d==igroup) ? (1:length(axlist[d])) : (d==ivsaxis) ? axVal2Index(axlist[d],yval,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    cax = getMemHandle(cube,1,CartesianIndex(subcubedims))
    cay = getMemHandle(cube,1,CartesianIndex(subcubedims))
    dataslicex=getSubRange(cax,sliceargsx...)[1]
    dataslicey=getSubRange(cay,sliceargsy...)[1]

    xvals = r1(dataslicex)
    yvals = r1(dataslicey)

    nPoints = length(yvals)
    pointSize = min(25000/nPoints,50)

    if igroup > 0
      plotf = scatterplot
      jgroup = count_to(x->isa(x,Range),sliceargsx,igroup)
      gvals=repAx(dataslicex,jgroup,prepAx(axlist[igroup]))
      p=plotf(x=xvals,y=yvals,group=gvals,pointSize=pointSize)
    else
      plotf = scatterplot
      p=plotf(x=xvals,y=yvals,pointSize=pointSize)
    end
    xlab!(p,title=string(axlist[ivsaxis].values[xval]),ticks=10,tickSizeMajor= 5)
    ylab!(p,title=string(axlist[ivsaxis].values[yval]),ticks=10,tickSizeMajor= 5)
    p
  end
  if length(argvars)==0
    (igroup==0) && push!(fixedvarsEx.args,:(igroup=0))
    x=eval(:(cube->$plotfun2))
    return x(cube)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun2)
  liftex = Expr(:call,:map,lambda,signals...)
  myfun=eval(quote
  local li
  li(cube)=$liftex
end)
for w in widgets display(w) end
display(myfun(cube))
end
end
