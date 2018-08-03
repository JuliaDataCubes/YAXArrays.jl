module CubeIO
importall ..Cubes
importall ..DAT
importall ..CubeAPI
importall ..CubeAPI.CachedArrays
importall ..Proc
importall ..Mask
import DataArrays: isna
import DataArrays
exportmissval(x::AbstractFloat)=oftype(x,NaN)
exportmissval(x::Integer)=typemax(x)

function copyMAP(xout::AbstractArray,maskout::AbstractArray{UInt8},xin::AbstractArray,maskin::AbstractArray{UInt8})
    #Start loop through all other variables
    for (iout,vin,min) in zip(eachindex(xout),xin,maskin)
      if (x>UInt8(0)) || (x & FILLED)==FILLED
        xout[iout]=vin
      else
        xout[iout]=exportmissval(vin)
      end
      maskout[iout]=min
    end
end

import NetCDF.ncread, NetCDF.ncclose
import StatsBase.Weights
import StatsBase.sample
#function readLandSea(c::Cube)
#    m=ncread(joinpath(c.base_dir,"mask","mask.nc"),"mask")
#    scale!(m,OCEAN)
#    a1=LonAxis((c.config.grid_x0:(c.config.grid_width-1))*c.config.spatial_res+c.config.spatial_res/2-180.0)
#    a2=LatAxis(90.0-(c.config.grid_y0:(c.config.grid_height-1))*c.config.spatial_res-c.config.spatial_res/2)
#    ncclose(joinpath(c.base_dir,"mask","mask.nc"))
#    CubeMem(CubeAxis[a1,a2],m,m);
#end


function getSpatiaPointAxis(mask::CubeMem)
    a=Tuple{Float64,Float64}[]
    ax=axes(mask)
    ocval=OCEAN
    for (ilat,lat) in enumerate(ax[2].values)
        for (ilon,lon) in enumerate(ax[1].values)
            if (mask.mask[ilon,ilat] & ocval) != ocval
                push!(a,(lon,lat))
            end
        end
    end
    SpatialPointAxis(a)
end

function toPointAxis(aout,ain,loninds,latinds)
  xout, maskout = aout
  xin , maskin  = ain
  iout = 1
  for (ilon,ilat) in zip(loninds,latinds)
    xout[iout]=xin[ilon,ilat]
    maskout[iout]=maskin[ilon,ilat]
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
  axlist=axes(c)
  ilon=findAxis(LonAxis,axlist)
  ilat=findAxis(LatAxis,axlist)
  ilon>0 || error("Input cube must contain a LonAxis")
  ilat>0 || error("input cube must contain a LatAxis")
  lonax=axlist[ilon]
  latax=axlist[ilat]
  pointax = SpatialPointAxis([(pl[i,1],pl[i,2]) for i in 1:size(pl,1)])
  loninds = map(ll->axVal2Index(lonax,ll[1]),pointax.values)
  latinds = map(ll->axVal2Index(latax,ll[2]),pointax.values)
  incubes=InDims("Lon","Lat",miss=MaskMissing())
  outcubes=OutDims(pointax,miss=MaskMissing())
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
  axlist=axes(cdata)
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
   indims=InDims("Lon","Lat",miss=NaNMissing()),outdims=OutDims(sax2,miss=NaNMissing()),max_cache=1e8);
end
export sampleLandPoints

using NetCDF
import IterTools: product
function writefun(xout,xin,a,nd,cont_loop,filename;kwargs...)

  x = map((m,v)->m==0x00 ? v : oftype(v,-9999.0),xin[2],xin[1])

  count_vec = fill(-1,nd)
  start_vec = fill(1,nd)

  used_inds = Int[]
  for (k,v) in cont_loop
    count_vec[k] = 1
    ia = findfirst(i->i[1]==Symbol(v),a)
    start_vec[k] = a[ia][2][1]
    push!(used_inds,ia)
  end

  splinds = Iterators.filter(i->!in(i,used_inds),1:length(a))
  vn = join(string.([a[s][2][2] for s in splinds]),"_")
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
which means that the file will be stored with longitudes varuing fastest. 
"""
function exportcube(r::AbstractCubeData,filename::String;priorities = Dict("LON"=>1,"LAT"=>2,"TIME"=>3))

  ax = axes(r)
  ax_cont = collect(filter(i->isa(i,RangeAxis),ax))
  ax_cat  = filter(i->!isa(i,RangeAxis),ax)
  prir = map(i->get(priorities,uppercase(axname(i)),10),ax_cont)
  ax_cont=ax_cont[sortperm(prir)]
  dims = map(NcDim,ax_cont)
  isempty(ax_cat) && (ax_cat=[VariableAxis(["layer"])])
  it = map(i->i.values,ax_cat)
  vars = NcVar[NcVar(join(collect(string.(a)),"_"),dims,t=eltype(r),atts=Dict("missing_value"=>-9999.0)) for a in product(it...)]
  file = NetCDF.create(filename,vars)
  for d in dims
    ncwrite(d.vals,filename,d.name)
  end
  dl = map(i->i.dimlen,dims) |> cumprod
  isplit = findfirst(i->i>1e6,dl)
  isplit < 1 && (isplit=length(dl)+1)
  incubes = InDims(ax_cont[1:(isplit-1)]...,miss=MaskMissing())
  cont_loop = Dict(ii=>axname.(ax_cont[ii]) for ii in isplit:length(ax_cont))

  mapCube(writefun,r,length(ax_cont),cont_loop,filename,indims=incubes,include_loopvars=true,ispar=false)
  ncclose(filename)
  nothing
end
export exportcube
end
