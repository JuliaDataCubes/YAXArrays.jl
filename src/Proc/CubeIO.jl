module CubeIO
using ..Cubes
using ..DAT
using ..CubeAPI
using ..Proc

import ...ESDLTools: unmiss
import NetCDF.ncread, NetCDF.ncclose
import StatsBase.Weights
import StatsBase.sample
import Base.Iterators

function getSpatiaPointAxis(mask::CubeMem)
    a=Tuple{Float64,Float64}[]
    ax=caxes(mask)
    anew = Iterators.product(ax[1].values,ax[2].values)
    SpatialPointAxis(a)
end

function toPointAxis(aout,ain,loninds,latinds)
  iout = 1
  for (ilon,ilat) in zip(loninds,latinds)
    aout[iout]=ain[ilon,ilat]
    iout+=1
  end
end

"""
    extractLonLats(c::AbstractCubeData,pl::Matrix)

Extracts a list of longitude/latitude coordinates from a data cube. The coordinates
are specified through the matrix `pl` where `size(pl)==(N,2)` and N is the number
of extracted coordinates. Returns a data cube without `LonAxis` and `LatAxis` but with a
`SpatialPointAxis` containing the input locations.
"""
function extractLonLats(c::AbstractCubeData,pl::Matrix;kwargs...)
  size(pl,2)==2 || error("Coordinate list must have exactly 2 columns")
  axlist=caxes(c)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  ilon>0 || error("Input cube must contain a LonAxis")
  ilat>0 || error("input cube must contain a LatAxis")
  lonax=axlist[ilon]
  latax=axlist[ilat]
  pointax = SpatialPointAxis([(pl[i,1],pl[i,2]) for i in 1:size(pl,1)])
  loninds = map(ll->axVal2Index(lonax,ll[1]),pointax.values)
  latinds = map(ll->axVal2Index(latax,ll[2]),pointax.values)
  incubes=InDims("Lon","Lat")
  outcubes=OutDims(pointax)
  y=mapCube(toPointAxis,c,loninds,latinds;indims=incubes,outdims=outcubes,max_cache=1e8,kwargs...)
end
export extractLonLats

"""
    sampleLandPoints(cube, nsample;nomissing=false)

Get an area-weighted sample from all non-ocean grid cells. This will return a new Cube
where the `LonAxis` and `LatAxis` are condensed into a single `SpatialPointAxis` of
length `nsample`. If `nomissing=true` only grid cells will be selected which don't contain any missing values.
This makes sense for gap-filled cubes to make sure that grid cells with systematic seasonal gaps are not selected
in the sample.
"""
function sampleLandPoints(cdata::CubeAPI.AbstractCubeData,nsample::Integer,nomissing=false)
  axlist=caxes(cdata)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  if nomissing
    remAxes=filter(i->!(isa(i,LonAxis) || isa(i,LatAxis)),axlist)
    cm=reduceCube(i->any(ismissing,i),cdata,ntuple(i->typeof(remAxes[i]),length(remAxes)),outtype=(Bool,))
    m=map(i->(i ? OCEAN : VALID),cm.data)
    cm=CubeMem(CubeAxis[axlist[ilon],axlist[ilat]],m,m)
  else
    bs=ntuple(i->in(i,(ilon,ilat)) ? length(axlist[i]) : 1,length(axlist))
    sargs=ntuple(i->ifelse(in(i,(ilon,ilat)),1:length(axlist[i]),1),length(axlist))
    mh=getMemHandle(cdata,1,CartesianIndex(bs))
    a,m=getSubRange(mh,sargs...)
    m=copy(m)
    cm=CubeMem(CubeAxis[axlist[ilon],axlist[ilat]],m,m)
  end
  sax=getSpatiaPointAxis(cm);
  isempty(sax.values) && error("Could not find any valid coordinates to extract a sample from. Please check for systematic missing values if you set nomissing=true")
  w=Weights(map(i->cosd(i[2]),sax.values))
  sax2=SpatialPointAxis(sample(sax.values,w,nsample,replace=false))
  y=mapCube(toPointAxis,cdata,axlist[ilon],axlist[ilat],
   indims=InDims("Lon","Lat"),outdims=OutDims(sax2),max_cache=1e8);
end
export sampleLandPoints

using NetCDF
import Base.Iterators: product
function writefun(xout,xin::AbstractArray{Union{Missing,T}},a,nd,cont_loop,filename;kwargs...) where T

  x = map(ix->ismissing(ix) ? convert(T,-9999.0) : ix,xin)

  count_vec = fill(-1,nd)
  start_vec = fill(1,nd)

  used_syms = Symbol[]
  for (k,v) in cont_loop
    count_vec[k] = 1
    start_vec[k] = a[Symbol(v)][1]
    push!(used_syms,Symbol(v))
  end

  splinds = Iterators.filter(i->!in(i,used_syms),keys(a))
  vn = join(string.([a[s][2] for s in splinds]),"_")
  isempty(vn) && (vn="layer")
  @show start_vec
  @show count_vec
  @show vn
  @show a
  ncwrite(x,filename,vn,start=start_vec,count=count_vec)
end

"""
    exportcube(r::AbstractCubeData,filename::String)

Saves a cube object to a portable NetCDF file in `filename`.

When saving, every RangeAxis will be converted to an axis in the NetCDF cube,
while every categorical axis will be represented by a different variable
inside the resulting file. Dimensions will be ordered according to the
`priorities` keyword argument, which defaults to `Dict("LON"=>1,"LAT"=>2,"TIME"=>3)`,
which means that the file will be stored with longitudes varuing fastest.
"""
function exportcube(r::AbstractCubeData,filename::String;priorities = Dict("LON"=>1,"LAT"=>2,"TIME"=>3))

  ax = caxes(r)
  ax_cont = collect(filter(i->isa(i,RangeAxis),ax))
  ax_cat  = filter(i->!isa(i,RangeAxis),ax)
  prir = map(i->get(priorities,uppercase(axname(i)),10),ax_cont)
  ax_cont=ax_cont[sortperm(prir)]
  dims = map(NcDim,ax_cont)
  isempty(ax_cat) && (ax_cat=[VariableAxis(["layer"])])
  it = map(i->i.values,ax_cat)
  vars = NcVar[NcVar(join(collect(string.(a)),"_"),dims,t=unmiss(eltype(r)),atts=Dict("missing_value"=>-9999.0)) for a in product(it...)]
  file = NetCDF.create(filename,vars)
  for d in dims
    ncwrite(d.vals,filename,d.name)
  end
  dl = map(i->i.dimlen,dims) |> cumprod
  isplit = findfirst(i->i>5e7,dl)
  isplit isa Nothing && (isplit=length(dl)+1)
  incubes = InDims(ax_cont[1:(isplit-1)]...)
  cont_loop = Dict(ii=>axname(ax_cont[ii]) for ii in isplit:length(ax_cont))

  mapCube(writefun,r,length(ax_cont),cont_loop,filename,indims=incubes,include_loopvars=true,ispar=false,max_cache=5e7)
  ncclose(filename)
  nothing
end
export exportcube
end
