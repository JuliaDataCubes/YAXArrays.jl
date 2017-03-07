abstract MAPPlot <: CABLABPlots

type MAPPlotRGB <: MAPPlot
  xaxis
  yaxis
  rgbAxis
  dmin
  dmax
  c_1
  c_2
  c_3
  misscol
  oceancol
  cType
end
plotAxVars(p::MAPPlotRGB)=[
  FixedAx(p.xaxis,:ilon,"X Axis",true,false),
  FixedAx(p.yaxis,:ilat,"Y Axis",true,false),
  FixedAx(p.rgbAxis,:irgb,"RGB Axis", true, true),
  FixedVar(p.rgbAxis,p.c_1,:c_1,channel_names(p.cType)[1],true),
  FixedVar(p.rgbAxis,p.c_2,:c_2,channel_names(p.cType)[2],true),
  FixedVar(p.rgbAxis,p.c_3,:c_3,channel_names(p.cType)[3],true)
  ]
match_subCubeDims(::MAPPlotRGB) = quote (d==ilon || d==ilat) => length(axlist[d]);_=>1 end
match_indstart(::MAPPlotRGB)    = quote (d==ilon || d==ilat) => 1;d==irgb => axVal2Index(axlist[d],c_f,fuzzy=true) ; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::MAPPlotRGB)   = quote (d==ilon || d==ilat) => subcubedims[d];d==irgb => axVal2Index(axlist[d],c_f,fuzzy=true) ; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
nplotCubes(::MAPPlotRGB)=3
function getFixedVars(p::MAPPlotRGB,cube)
  quote
    oceancol=$(p.oceancol)
    misscol=$(p.misscol)
  end
end
plotCall(p::MAPPlotRGB) = quote
  rgbar=getRGBAR($(p.cType),a_1,m_1,a_2,m_2,a_3,m_3,(mir,mig,mib),(mar,mag,mab),misscol,oceancol)
  pngbuf=IOBuffer()
  show(pngbuf,"image/png",rgbar)
  themap=compose(context(0,0,1,1),bitmap("image/png",pngbuf.data,0,0,1,1))
end
getafterEx(p::MAPPlotRGB)=p.dmin==p.dmax ? :((mir,mar,mig,mag,mib,mab)=(getMinMax(a_1,m_1)...,getMinMax(a_2,m_2)...,getMinMax(a_3,m_3)...)) : :(mi=$(dmin);ma=$(dmax))



abstract MAPPlotMapped <: MAPPlot

plotAxVars(p::MAPPlotMapped)=[FixedAx(p.xaxis,:ilon,"X Axis",true,false),FixedAx(p.yaxis,:ilat,"Y Axis",true,false)]
match_subCubeDims(::MAPPlotMapped) = quote (d==ilon || d==ilat) => length(axlist[d]); _=>1 end
match_indstart(::MAPPlotMapped)    = quote (d==ilon || d==ilat) => 1; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::MAPPlotMapped)      = quote (d==ilon || d==ilat) => subcubedims[d]; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
nplotCubes(::MAPPlotMapped)=1
max_indim(::MAPPlot)=2
min_indim(::MAPPlot)=2
n_fixedindim(::MAPPlot)=0


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
    oceancol=$(p.oceancol)
    misscol=$(p.misscol)
    iscategorical=true
    legPos=:right
  end
end
plotCall(::MAPPlotCategory) = :(_makeMap(a_1,m_1,0.0,0.0,colorm,oceancol,misscol,legPos,iscategorical,false))


type MAPPlotContin <: MAPPlotMapped
  colorm
  dmin
  dmax
  symmetric
  oceancol
  misscol
  xaxis
  yaxis
end
function getFixedVars(p::MAPPlotContin,cube)
  quote
    colorm=$(p.colorm)
    oceancol=$(p.oceancol)
    misscol=$(p.misscol)
    symmetric=$(p.symmetric)
    iscategorical=false
    legPos=:bottom
  end
end
getafterEx(p::MAPPlotContin)=p.dmin==p.dmax ? :((mi,ma)=getMinMax(a_1,m_1)) : :(mi=$(p.dmin);ma=$(p.dmax))
plotCall(::MAPPlotContin)   = :(_makeMap(a_1,m_1,mi,ma,colorm,oceancol,misscol,legPos,iscategorical,symmetric))

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
    plotGeneric(MAPPlotContin(colorm,dmin,dmax,symmetric,oceancol,misscol,xaxis,yaxis),cube;kwargs...)
  end
end

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
  c1 = nothing, c2=nothing, c3=nothing, cType=XYZ, xaxis=LonAxis,yaxis=LatAxis,kwargs...)

  isa(rgbAxis,CubeAxis) && (rgbAxis=typeof(rgbAxis))

  dmin,dmax = typed_dminmax2(T,dmin,dmax)
  axlist    = axes(cube)

  irgb = findAxis(rgbAxis,axlist)
  if length(axlist[irgb])==3 && c1==nothing && c2==nothing && c3==nothing
    c1=1
    c2=2
    c3=3
  end

  return plotGeneric(MAPPlotRGB(xaxis,yaxis,rgbAxis,dmin,dmax,c1,c2,c3,misscol,oceancol,cType),cube;kwargs...)
end

@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for j=1:size(a,2),i=1:size(a,1)]
@noinline getRGBAR(cType,ar,mr,ag,mg,ab,mb,mi,ma,misscol,oceancol)=[RGB(val2col(cType,ar[i,j],mr[i,j],ag[i,j],mg[i,j],ab[i,j],mb[i,j],mi,ma,misscol,oceancol)) for j=1:size(ar,2),i=1:size(ar,1)]
@noinline getRGBAR(a,m,colorm::Dict,mi,ma,misscol,oceancol)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,misscol,oceancol) for j=1:size(a,2),i=1:size(a,1)]

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

function _makeMap{T}(a::Array{T},m,mi,ma,colorm,oceancol,misscol,legPos,iscategorical,symmetric)
  if iscategorical
    colorm,colorm2=colorm
  else
    mi==ma && ((mi,ma)=getMinMax(a,m,symmetric=symmetric))
  end
  rgbar = getRGBAR(a,m,colorm,convert(T,mi),convert(T,ma),misscol,oceancol)
  pngbuf=IOBuffer()
  show(pngbuf,"image/png",rgbar)
  legheight=legPos==:bottom ? max(0.1*Measures.h,1.6Measures.cm) : 0Measures.h
  legwidth =legPos==:right  ? max(0.2*Measures.w,3.2Measures.cm) : 0Measures.w
  themap=compose(context(0,0,1Measures.w-legwidth,1Measures.h-legheight),bitmap("image/png",pngbuf.data,0,0,1,1))
  theleg=iscategorical ? getlegend(colorm2,legwidth) : getlegend(mi,ma,colorm,legheight)
  compose(context(),themap,theleg)
end



function makeifs(alist)
    filter!(i->i.head!=:line,alist)
    if length(alist)==1
        (alist[1].head==:(=>) && alist[1].args[1]==:(_)) || error("Expecting _=>something as default argument")
        return (alist[1].args[2])
    else
        return Expr(:if,alist[1].args[1],alist[1].args[2],makeifs(alist[2:end]))
    end
end
