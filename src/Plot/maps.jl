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
#plotAxVars(p::MAPPlotMapped)=[(p.xaxis,:ilon,"X Axis",true),(p.yaxis,:ilat,"Y Axis",true),(p.rgbAxis,:irgb,"RGB Axis",true)]
#match_subCubeDims(::MAPPlotMapped) = quote (d==ilon || d==ilat) => length(axlist[d]); _=>1 end
#match_indstart(::MAPPlotMapped)    = quote (d==ilon || d==ilat) => 1; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
#match_indend(::MAPPlotMapped)      = quote (d==ilon || d==ilat) => subcubedims[d]; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
#nplotCubes(::MAPPlotMapped)=1

abstract MAPPlotMapped <: MAPPlot

plotAxVars(p::MAPPlotMapped)=[(p.xaxis,:ilon,"X Axis",true),(p.yaxis,:ilat,"Y Axis",false)]
match_subCubeDims(::MAPPlotMapped) = quote (d==ilon || d==ilat) => length(axlist[d]); _=>1 end
match_indstart(::MAPPlotMapped)    = quote (d==ilon || d==ilat) => 1; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
match_indend(::MAPPlotMapped)      = quote (d==ilon || d==ilat) => subcubedims[d]; _=> axVal2Index(axlist[d],v_d,fuzzy=true) end
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

  return plotGeneric(MAPPlotRGB(xaxis,yaxis,rgbAxis,dmin,dmax,c1,c2,c3,misscol,oceancol,cType))
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

@noinline getRGBAR(a,m,colorm,mi,ma,misscol,oceancol)=RGB{U8}[val2col(a[i,j],m[i,j],colorm,mi,ma,misscol,oceancol) for j=1:size(a,2),i=1:size(a,1)]
@noinline getRGBAR(cType,ar,mr,ag,mg,ab,mb,mi,ma,misscol,oceancol)=[RGB(val2col(cType,ar[i,j],mr[i,j],ag[i,j],mg[i,j],ab[i,j],mb[i,j],mi,ma,misscol,oceancol)) for j=1:size(ar,1),i=1:size(ar,2)]
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

getafterEx(::CABLABPlots)=Expr(:block)

function makeifs(alist)
    filter!(i->i.head!=:line,alist)
    if length(alist)==1
        (alist[1].head==:(=>) && alist[1].args[1]==:(_)) || error("Expecting _=>something as default argument")
        return (alist[1].args[2])
    else
        return Expr(:if,alist[1].args[1],alist[1].args[2],makeifs(alist[2:end]))
    end
end
