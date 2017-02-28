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
import Match: @match

typealias U8 Normed{UInt8,8}
#import Patchwork.load_js_runtime


abstract CABLABPlots



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

function getMinMax(x,mask;symmetric=false)
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
  #println(x)
  if !isnan(x) && x<typemax(x) && m==VALID || m==FILLED
    i=min(N,max(1,ceil(Int,(x-mi)/(ma-mi)*N)))
    return colorm[i]
  elseif (m & OCEAN)==OCEAN
    return oceancol
  else
    return misscol
  end
end

function val2col(cType,xr,mr,xg,mg,xb,mb,mi,ma,misscol,oceancol)
  mi1,mi2,mi3=channel_min(cType)
  ma1,ma2,ma3=channel_max(cType)
  if !isnan(xr) && !isnan(xg) && !isnan(xb) && (((mr | mg | mb) & MISSING)==VALID)
    return cType((xr-mi[1])/(ma[1]-mi[1])*(ma1-mi1)+mi1,(xg-mi[2])/(ma[2]-mi[2])*(ma2-mi2)+mi2,(xb-mi[3])/(ma[3]-mi[3])*(ma3-mi3)+mi3)
  elseif (mr & OCEAN)==OCEAN
    return oceancol
  else
    return misscol
  end
end

function val2col(x,m,colorm::Dict,misscol,oceancol)
  if !isnan(x) && m==VALID || m==FILLED
    return get(colorm,x,misscol)
  elseif (m & OCEAN)==OCEAN
    return oceancol
  else
    return misscol
  end
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

function _makeMap(a,m,mi,ma,colorm,colorm2,oceancol,misscol,legPos,iscategorical,symmetric)
  if iscategorical
    colorm,colorm2=colorm
  else
    mi==ma && ((mi,ma)=getMinMax(a,m,symmetric=symmetric))
  end
  rgbar = getRGBAR(a,m,colorm,convert($T,mi),convert($T,ma),misscol,oceancol,nx,ny)
  pngbuf=IOBuffer()
  show(pngbuf,"image/png",rgbar)
  legheight=legPos==:bottom ? max(0.1*Measures.h,1.6Measures.cm) : 0Measures.h
  legwidth =legPos==:right  ? max(0.2*Measures.w,3.2Measures.cm) : 0Measures.w
  themap=compose(context(0,0,1Measures.w-legwidth,1Measures.h-legheight),bitmap("image/png",pngbuf.data,0,0,1,1))
  getlegend(mi,ma,colorm,legheight)
  compose(context(),themap,theleg)
end

abstract MAPPlot <: CABLABPlots
abstract MAPPlotMapped <: MAPPlot

plotAxVars(p::MAPPlotMapped)=[(p.xaxis,:ilon,"X Axis",true),(p.yaxis,:ilat,"Y Axis",false)]
match_subCubeDims(::MAPPlotMapped) = quote (ilon || ilat) => length(axlist[d]); _=>1 end
match_indstart(::MAPPlotMapped,::Int)    = quote (ilon || ilat) => 1; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::MAPPlotMapped,::Int)      = quote (ilon || ilat) => subcubedims[d]; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
plotCall(::MAPPlotMapped) = :(_makeMap(a_1,m_1,mi,ma,colorm,oceancol,misscol,legPos,iscategorical,symmetric))
nplotCubes(::MAPPlotMapped)=1

type MAPPlotCategory <: MAPPlotMapped
  colorm
  colorm2
  oceancol
  misscol
  xaxis
  yaxis
end
function getFixedVars(p::MAPPlotCategory,cube)
  quote
    colorm=($(p.colorm),$(p.colorm2))
    iscategorical=true
    legPos=:right
  end
end

type MAPPlotContin <: MAPPlotMapped
  colorm
  dmin
  dmax
  oceancol
  misscol
  xaxis
  yaxis
end
function getFixedVars(p::MAPPlotMapped,cube)
  quote
    colorm=$(p.colorm)
    iscategorical=false
    legPos=:bottom
    $(p.dmin==p.dmax ? :((mi,ma)=getMinMax(a_1,m_1)) : :(mi=$p.(dmin);ma=$(p.dmax)))
  end

end

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

    subcubedims = @ntuple $nax d->@match d $(match_subCubeDims(plotObj))
    sd2 = filter(i->i>1,subcubedims)

    @nexprs $nCubes f->begin
      a_f        = zeros(eltype(cube), subcubedims)
      m_f        = zeros(UInt8,        subcubedims)
      indstart_f = @ntuple $nax d->@match d $(match_indstart(plotObj,f))
      indend_f   = @ntuple $nax d->@match d $(match_indend(plotObj,f))

      _read(cube,(a_f,m_f),CartesianRange(CartesianIndex(indstart_f),CartesianIndex(ind_f)))
      a_f,m_f = reshape(a_f,sd2...),reshape(m_f,sd2...)
    end

    $(plotCall(plotObj))
  end
  return plotfun
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



"""
`plotMAP(cube::AbstractCubeData; dmin=datamin, dmax=datamax, colorm=colormap("oranges"), oceancol=colorant"darkblue", misscol=colorant"gray", kwargs...)`

Map plotting tool for cube objects, can be called on any type of cube data

### Keyword arguments

* `dmin, dmax` Minimum and maximum value to be used for color transformation
* `colorm` colormap to be used. Find a list of colormaps in the [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) package
* `oceancol` color to fill the ocean with, defaults to `colorant"darkblue"`
* `misscol` color to represent missing values, defaults to `colorant"gray"`
* `symmetric` make the color scale symmetric around zero
* `labels` given a list of labels this will create a plot with a non-continouous color scale where integer cube values [1..N] are mapped to the given labels.
* `dim=value` can set other dimensions to certain values, for example `var="air_temperature_2m"` will fix the variable for the resulting plot

If a dimension is neither longitude or latitude and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotMAP{T}(cube::CubeAPI.AbstractCubeData{T};xaxis=LonAxis, yaxis=LatAxis, dmin=zero(T),dmax=zero(T),
  colorm=:inferno,oceancol=colorant"darkblue",misscol=colorant"gray",symmetric=false,kwargs...)

  isa(colorm,Symbol) && (colorm=get(namedcolms,colorm,namedcolms[:inferno]))
  dmin,dmax=typed_dminmax(T,dmin,dmax)
  axlist=axes(cube)

  props=cube.properties

  if haskey(props,"labels")
    labels = props["labels"]
    _colorm  = distinguishable_colors(length(labels)+2,[misscol,oceancol])[3:end]
    colorm   = Dict(k=>_colorm[i] for (i,k) in enumerate(keys(labels)))
    colorm2  = Dict(k=>_colorm[i] for (i,k) in enumerate(values(labels)))
    plotGeneric(MAPPlotCategory(colorm,colorm2,oceancol,misscol,xaxis,yaxis),cube;kwargs...)
  else
    plotGeneric(MAPPlotContin(colorm,dmin,dmax,oceancol,misscol,xaxis,yaxis),cube;kwargs...)
  end
end

@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for j=1:ny,i=1:nx]
@noinline getRGBAR(cType,ar,mr,ag,mg,ab,mb,mi,ma,misscol,oceancol,nx,ny)=[RGB(val2col(cType,ar[i,j],mr[i,j],ag[i,j],mg[i,j],ab[i,j],mb[i,j],mi,ma,misscol,oceancol)) for j=1:ny,i=1:nx]
@noinline getRGBAR(a,m,colorm::Dict,misscol,oceancol,nx,ny)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,misscol,oceancol) for j=1:ny,i=1:nx]

using ColorTypes
channel_max(d::DataType)="Colortype $d not yet added"
typealias RGBlike Union{Type{XYZ},Type{RGB},Type{xyY}}
typealias HSVlike Union{Type{HSV},Type{HSI},Type{HSL}}
typealias Lablike Union{Type{Lab},Type{Luv}}
channel_min(::RGBlike)=(0.0,0.0,0.0)
channel_max(::RGBlike)=(1.0,1.0,1.0)
channel_min(::Lablike)=(0.0,-170.0,-100.0)
channel_max(::Lablike)=(100.0,100.0,150.0)
channel_min(::HSVlike)=(0.0,0.0,0.0)
channel_max(::HSVlike)=(360.0,1.0,1.0)
channel_names(::Type{RGB})=("R","G","B")
channel_names(::Type{XYZ})=("X","Y","Z")
channel_names(::Type{xyY})=("x","y","Y")
channel_names(::Type{HSV})=("H","S","V")
channel_names(::Type{HSI})=("H","S","I")
channel_names(::Type{HSL})=("H","S","L")
channel_names(::Type{Lab})=("L","a","b")
channel_names(::Type{Luv})=("L","u","v")


"""
`plotMAPRGB(cube::AbstractCubeData; dmin=datamin, dmax=datamax, colorm=colormap("oranges"), oceancol=colorant"darkblue", misscol=colorant"gray", kwargs...)`

Map plotting tool for colored plots that use up to 3 variables as input into the several color channels.
Several color representations from the `Colortypes.jl` package are supported, so that besides RGB (XYZ)-plots
one can create HSL, HSI, HSV or Lab and Luv plots.

### Keyword arguments

* `dmin, dmax` Minimum and maximum value to be used for color transformation, can be either a single value or a tuple, when min/max values are given for each channel
* `rgbAxis` which axis should be used to select RGB channels from
* `oceancol` color to fill the ocean with, defaults to `colorant"darkblue"`
* `misscol` color to represent missing values, defaults to `colorant"gray"`
* `labels` given a list of labels this will create a plot with a non-continouous color scale where integer cube values [1..N] are mapped to the given labels.
* `cType` ColorType to use for the color representation. Can be one of `RGB`, `XYZ`, `Lab`, `Luv`, `HSV`, `HSI`, `HSL`
* `dim=value` can set other dimensions to certain values, for example `var="air_temperature_2m"` will fix the variable for the resulting plot


If a dimension is neither longitude or latitude and is not fixed through an additional keyword, a slider or dropdown menu will appear to select the axis value.
"""
function plotMAPRGB{T}(cube::CubeAPI.AbstractCubeData{T};dmin=zero(T),dmax=zero(T),
  rgbAxis=VariableAxis,oceancol=colorant"darkblue",misscol=colorant"gray",symmetric=false,
  c1 = nothing, c2=nothing, c3=nothing, cType=XYZ, kwargs...)
  isa(rgbAxis,CubeAxis) && (rgbAxis=typeof(rgbAxis))

  dmin,dmax = typed_dminmax2(T,dmin,dmax)
  axlist    = axes(cube)

  irgb = findAxis(rgbAxis,axlist)
  ilon = findAxis(LonAxis,axlist)
  ilat = findAxis(LatAxis,axlist)

  p    = getFrontPerm(cube,(axlist[irgb],axlist[ilon],axlist[ilat]))
  (p[1]==1 && p[2]==2 && p[3]==3) || (cube=permutedims(cube,p))
  irgb,ilon,ilat=(1,2,3)
  axlist=axes(cube)
  sliders=Any[]
  signals=Signal[]
  argvars=Symbol[]
  ivarax=0
  nvar=0
  nlon=length(axlist[1])
  nlat=length(axlist[2])
  fixedvarsEx=quote end
  labels   = nothing
  mimaex   = dmin==dmax ? :((mir,mar,mig,mag,mib,mab)=(getMinMax(ar,mr)...,getMinMax(ag,mg)...,getMinMax(ab,mb)...)) : :(mi=$(dmin);ma=$(dmax))
  rgbarEx  = :(rgbar=getRGBAR($cType,ar,mr,ag,mg,ab,mb,(mir,mig,mib),(mar,mag,mab),misscol,oceancol,nx,ny))
  fixedAxes=CubeAxis[]
  if length(axlist[irgb])==3 && c1==nothing && c2==nothing && c3==nothing
    c1=1
    c2=2
    c3=3
  end
  if c1==nothing
    w=getWidget(axlist[irgb],label=channel_names(cType)[1])
    push!(sliders,w)
    push!(signals,signal(w))
    push!(argvars,:c1)
  else
    push!(fixedvarsEx.args,:(c1=$c1))
  end
  if c2==nothing
    w=getWidget(axlist[irgb],label=channel_names(cType)[2])
    push!(sliders,w)
    push!(signals,signal(w))
    push!(argvars,:c2)
  else
    push!(fixedvarsEx.args,:(c2=$c2))
  end
  if c3==nothing
    w=getWidget(axlist[irgb],label=channel_names(cType)[3])
    push!(sliders,w)
    push!(signals,signal(w))
    push!(argvars,:c3)
  else
    push!(fixedvarsEx.args,:(c3=$c3))
  end
  for (sy,val) in kwargs
    ivalaxis=findAxis(string(sy),axlist)
    ivalaxis>3 || error("Axis $sy not found")
    s=Symbol("v_$ivalaxis")
    push!(fixedvarsEx.args,:($s=$val))
    push!(fixedAxes,axlist[ivalaxis])
  end
  for iax=4:length(axlist)
    if !in(axlist[iax],fixedAxes)
      w=getWidget(axlist[iax])
      push!(sliders,w)
      push!(signals,signal(w))
      push!(argvars,Symbol(string("v_",iax)))
    end
  end
  nax=length(axlist)
  plotfun=quote
    axlist=axes(cube)
    $fixedvarsEx
    subcubedims = @ntuple $nax d->(d==$ilon || d==$ilat) ? length(axlist[d]) : 1
    ar,ag,ab = zeros(eltype(cube),subcubedims),zeros(eltype(cube),subcubedims),zeros(eltype(cube),subcubedims)
    mr,mg,mb = zeros(UInt8,subcubedims),       zeros(UInt8,subcubedims),       zeros(UInt8,subcubedims)
    ind1r    = @ntuple $nax d->(d==$ilon || d==$ilat) ? 1                 : d==$irgb ? axVal2Index(axlist[d],c1,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    ind1g    = @ntuple $nax d->(d==$ilon || d==$ilat) ? 1                 : d==$irgb ? axVal2Index(axlist[d],c2,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    ind1b    = @ntuple $nax d->(d==$ilon || d==$ilat) ? 1                 : d==$irgb ? axVal2Index(axlist[d],c3,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    ind2r    = @ntuple $nax d->(d==$ilon || d==$ilat) ? length(axlist[d]) : d==$irgb ? axVal2Index(axlist[d],c1,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    ind2g    = @ntuple $nax d->(d==$ilon || d==$ilat) ? length(axlist[d]) : d==$irgb ? axVal2Index(axlist[d],c2,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    ind2b    = @ntuple $nax d->(d==$ilon || d==$ilat) ? length(axlist[d]) : d==$irgb ? axVal2Index(axlist[d],c3,fuzzy=true) : axVal2Index(axlist[d],v_d,fuzzy=true)
    _read(cube,(ar,mr),CartesianRange(CartesianIndex(ind1r),CartesianIndex(ind2r)))
    _read(cube,(ag,mg),CartesianRange(CartesianIndex(ind1g),CartesianIndex(ind2g)))
    _read(cube,(ab,mb),CartesianRange(CartesianIndex(ind1b),CartesianIndex(ind2b)))
    nx,ny=subcubedims[2],subcubedims[3]
    ar,mr = reshape(ar,(nx,ny)), reshape(mr,(nx,ny))
    ag,mg = reshape(ag,(nx,ny)), reshape(mg,(nx,ny))
    ab,mb = reshape(ab,(nx,ny)), reshape(mb,(nx,ny))
    $mimaex
    oceancol=$oceancol
    misscol=$misscol
    $rgbarEx
    pngbuf=IOBuffer()
    show(pngbuf,"image/png",rgbar)
    themap=compose(context(0,0,1,1),bitmap("image/png",pngbuf.data,0,0,1,1))
    #compose(context(),themap)
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
for w in sliders display(w) end
myfun(cube)
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
