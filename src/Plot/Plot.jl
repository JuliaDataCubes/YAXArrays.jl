module Plot
export plotTS, plotMAP, plotXY
importall ..Cubes
importall ..CubeAPI
importall ..CubeAPI.Mask
importall ..CubeAPI.CachedArrays
import ..DAT
import ..DAT: findAxis,getFrontPerm
import ..Cubes.Axes.axname
import Reactive: Signal
import Interact: slider, dropdown, signal, togglebutton, togglebuttons
import Vega: lineplot, barplot, groupedbar
import Images: Image
import Colors: RGB, @colorant_str, colormap, U8
import DataStructures: OrderedDict
import Base.Cartesian: @ntuple,@nexprs
import Patchwork.load_js_runtime
import Measures

#import Patchwork.load_js_runtime
ga=[]


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
getWidget(x::SpatialPointAxis)=slider(1:length(x),label="Spatial Point")

plotTS(x;kwargs...)=plotXY(x,xaxis=TimeAxis;kwargs...)

"""
`plotXY(cube::AbstractCubeData; group=0, xaxis=-1, kwargs...)`

Generic plotting tool for cube objects, can be called on any type of cube data.

### Keyword arguments

* `xaxis` which axis is to be used as x axis. Can be either an axis Datatype or a string. Short versions of axes names are possible as long as the axis can be uniquely determined.
* `group` it is possible to group the plot by a categorical axis. Can be either an axis data type or a string.
* `dim=value` can set other dimensions to certain values, for example `lon=51.5` will fix the longitude for the resulting plot

If a dimension is not the x axis or group variable and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
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
    subcubedims=@ntuple $nax d->(d==ixaxis || d==igroup) ? length(axlist[d]) : 1
    sliceargs=@ntuple $nax d->(d==ixaxis || d==igroup) ? (1:length(axlist[d])) : axVal2Index(axlist[d],v_d)
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
  myfun=eval(quote
    local li
    li(cube)=$liftex
  end)
  for w in widgets display(w) end
  display(myfun(cube))
end

function getMinMax(x,mask;symmetric=false,squeeze=1.0)
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
    mi,ma=(mi,mi+1)
  end
  if symmetric
    m=max(abs(mi),abs(ma))
    mi=-m
    ma=m
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

import PlotUtils.optimize_ticks
import PlotUtils.cgrad
import Colors.@colorant_str
import Compose: rectangle, text, line, compose, context, stroke, svgattribute, bitmap, HCenter, VBottom
const namedcolms=Dict(
  :viridis=>[cgrad(:viridis)[ix] for ix in linspace(0,1,100)],
  :magma=>[cgrad(:magma)[ix] for ix in linspace(0,1,100)],
  :inferno=>[cgrad(:inferno)[ix] for ix in linspace(0,1,100)],
  :plasma=>[cgrad(:plasma)[ix] for ix in linspace(0,1,100)])
typed_dminmax{T<:Integer}(::Type{T},dmin,dmax)=(Int(dmin),Int(dmax))
typed_dminmax{T<:AbstractFloat}(::Type{T},dmin,dmax)=(Float64(dmin),Float64(dmax))

"""
`plotMAP(cube::AbstractCubeData; dmin=datamin, dmax=datamax, colorm=colormap("oranges"), oceancol=colorant"darkblue", misscol=colorant"gray", kwargs...)`

Map plotting tool for cube objects, can be called on any type of cube data

### Keyword arguments

* `dmin, dmax` Minimum and maximum value to be used for color transformation
* `colorm` colormap to be used. Find a list of colormaps in the [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) package
* `oceancol` color to fill the ocean with, defaults to `colorant"darkblue"`
* `misscol` color to represent missing values, defaults to `colorant"gray"`
* `dim=value` can set other dimensions to certain values, for example `var="air_temperature_2m"` will fix the variable for the resulting plot

If a dimension is neither longitude or latitude and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotMAP{T}(cube::CubeAPI.AbstractCubeData{T};dmin=zero(T),dmax=zero(T),
  colorm=:inferno,oceancol=colorant"darkblue",misscol=colorant"gray",symmetric=false,kwargs...)
  isa(colorm,Symbol) && (colorm=namedcolms[colorm])
  dmin,dmax=typed_dminmax(T,dmin,dmax)
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
  fixedvarsEx=quote end
  fixedAxes=CubeAxis[]
  for (sy,val) in kwargs
    ivalaxis=findAxis(string(sy),axlist)
    ivalaxis>2 || error("Axis $sy not found")
    s=Symbol(Cubes.Axes.axname(axlist[ivalaxis]))
    push!(fixedvarsEx.args,:($s=$val))
    push!(fixedAxes,axlist[ivalaxis])
  end
  for iax=3:length(axlist)
    if in(axlist[iax],fixedAxes)
      push!(sliceargs,Symbol(Cubes.Axes.axname(axlist[iax])))
    else
      if isa(axlist[iax],RangeAxis)
        push!(sliders,slider(1:length(axlist[iax].values),label="Time Step"))
        push!(signals,signal(sliders[end]))
        push!(sliceargs,:time)
        push!(argvars,:time)
        display(sliders[end])
      elseif isa(axlist[iax],CategoricalAxis)
        ivarax=iax
        push!(sliceargs,Symbol(Cubes.Axes.axname(axlist[iax])))
        push!(argvars,Symbol(Cubes.Axes.axname(axlist[iax])))
        nvar=length(axlist[iax])
        varButtons=togglebuttons([(axlist[iax].values[i],i) for i=1:length(axlist[iax].values)])
        push!(sliders,varButtons)
        push!(signals,signal(varButtons))
        display(varButtons)
      end
    end
  end
  push!(ga,getMemHandle(cube,1,CartesianIndex(ntuple(i->subcubedims[i],length(axlist)))))
  lga=length(ga)
  dataslice=Expr(:call,:getSubRange,:(ga[$lga]),sliceargs...)
  mimaex = dmin==dmax ? :((mi,ma)=getMinMax(a,m,symmetric=$symmetric)) : :(mi=$(dmin);ma=$(dmax))
  plotfun=quote
    $fixedvarsEx
    a,m=$dataslice
    nx,ny=size(a)
    $mimaex
    colorm=$colorm
    oceancol=$oceancol
    misscol=$misscol
    rgbar=getRGBAR(a,m,colorm,convert($T,mi),convert($T,ma),misscol,oceancol,nx,ny)
    pngbuf=IOBuffer()
    show(pngbuf,"image/png",Image(rgbar,Dict("spatialorder"=>["x","y"])))
    legheight=max(0.1*Measures.h,1.6Measures.cm)
    themap=obj=compose(context(0,0,1,1Measures.h-legheight),bitmap("image/png",pngbuf.data,0,0,1,1))
    theleg=getlegend(mi,ma,colorm,legheight)
    compose(context(),themap,theleg)
  end
  lambda = Expr(:(->), Expr(:tuple, argvars...),plotfun)
  if length(argvars)==0
    x=eval(lambda)
    return x()
  end
  liftex = Expr(:call,:map,lambda,signals...)
  pf = gensym()
  myfun=eval(:($(pf)()=$liftex))
  myfun()
end
@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for i=1:nx,j=1:ny]

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
end
