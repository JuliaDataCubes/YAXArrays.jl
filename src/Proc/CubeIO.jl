module CubeIO
using ..Cubes
using ..DAT
using ..Proc

import NetCDF.ncread, NetCDF.ncclose
import StatsBase.Weights
import StatsBase.sample
import Base.Iterators


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
  ncwrite(x,filename,vn,start=start_vec,count=count_vec)
end

"""
    exportcube(r::AbstractCubeData,filename::String)

Saves a cube object to a portable NetCDF file in `filename`.

When saving, every RangeAxis will be converted to an axis in the NetCDF cube,
while every categorical axis will be represented by a different variable
inside the resulting file. Dimensions will be ordered according to the
`priorities` keyword argument, which defaults to `Dict("LON"=>1,"LAT"=>2,"TIME"=>3)`,
which means that the file will be stored with longitudes varying fastest.
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
  elt = Base.nonmissingtype(eltype(r))
  vars = NcVar[NcVar(join(collect(string.(a)),"_"),dims,t=elt,atts=Dict("missing_value"=>convert(elt,-9999.0))) for a in product(it...)]
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
  NetCDF.close(file)
  nothing
end
export exportcube
end
