module CubeIO

import NetCDF.ncread, NetCDF.ncclose
import Base.Iterators
import ...Cubes: saveCube, check_overwrite, getsavefolder, cubechunks, AbstractCubeData, caxes,
  axname
import ...Cubes.Axes: findAxis, CategoricalAxis, axVal2Index, RangeAxis
import ...DAT: InDims, OutDims, mapCube
import Zarr: ZArray


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
  ilon=findAxis("Lon",axlist)
  ilat=findAxis("Lat",axlist)
  ilon>0 || error("Input cube must contain a LonAxis")
  ilat>0 || error("input cube must contain a LatAxis")
  lonax=axlist[ilon]
  latax=axlist[ilat]
  pointax = CategoricalAxis("SpatialPoint", [(pl[i,1],pl[i,2]) for i in 1:size(pl,1)])
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
function exportcube(r::AbstractCubeData,filename::String;priorities = Dict("LON"=>1,"LAT"=>2,"TIME"=>3), proj=epsg4326)

  ax = caxes(r)
  ax_cont = collect(filter(i->isa(i,RangeAxis),ax))
  ax_cat  = filter(i->!isa(i,RangeAxis),ax)
  prir = map(i->get(priorities,uppercase(axname(i)),10),ax_cont)
  ax_cont=ax_cont[sortperm(prir)]
  dims = map(NcDim,ax_cont)
  isempty(ax_cat) && (ax_cat=[VariableAxis(["layer"])])
  it = map(i->i.values,ax_cat)
  elt = Base.nonmissingtype(eltype(r))
  vars = NcVar[NcVar(join(collect(string.(a)),"_"),dims,t=elt,atts=Dict("missing_value"=>convert(elt,-9999.0), "grid_mapping" => proj["grid_mapping_name"])) for a in product(it...)]
  file = NetCDF.create(filename,vars)
  for d in dims
    ncwrite(d.vals,filename,d.name)
  end
  nccreate(filename, proj["grid_mapping_name"])
  ncputatt(filename, proj["grid_mapping_name"], proj)
  dl = map(i->i.dimlen,dims) |> cumprod
  isplit = findfirst(i->i>5e7,dl)
  isplit isa Nothing && (isplit=length(dl))
  incubes = InDims(ax_cont[1:(isplit-1)]...)
  cont_loop = Dict(ii=>axname(ax_cont[ii]) for ii in isplit:length(ax_cont))
  mapCube(writefun,r,length(ax_cont),cont_loop,filename,indims=incubes,include_loopvars=true,ispar=false,max_cache=5e8,
  nthreads=[1])
  nothing
end

import Zarr: NoCompressor

function saveCube(c::AbstractCubeData, name::AbstractString; overwrite = false, chunksize = cubechunks(c), compressor=NoCompressor(), max_cache=1e8)
  allax = caxes(c)
  firstaxes = findall(i->i>1,chunksize)
  lastaxes = setdiff(1:length(allax),firstaxes)
  allax = allax[[firstaxes;lastaxes]]
  dl = cumprod(length.(caxes(c)))
  isplit = findfirst(i->i>max_cache/sizeof(eltype(c)),dl)
  isplit isa Nothing && (isplit=length(dl)+1)
  forcesingle = (isplit+1)<length(firstaxes)
  axn = axname.(allax[1:isplit-1])
  indims = InDims(axn...)
  path = getsavefolder(name)
  check_overwrite(path,overwrite)
  outdims = OutDims(axn..., retcubetype=ZArray,chunksize=chunksize[1:length(axn)], compressor=compressor, path = path)
  if forcesingle
    nprocs()>1 && println("Forcing single core processing because of bad chunk size")
    o = mapCube(copyto!,c,indims=indims, outdims=outdims,ispar=false,max_cache=max_cache)
  else
    o = mapCube(copyto!,c,indims=indims, outdims=outdims,max_cache=max_cache)
  end
end

export exportcube

global const projection = Dict(
"grid_mapping_name" => "transverse_mercator",
"longitude_of_central_meridian" => -9. ,
"false_easting" => 500000. ,
"false_northing" => 0. ,
"latitude_of_projection_origin" => 0. ,
"scale_factor_at_central_meridian" => 0.9996,
"long_name" => "CRS definition",
"longitude_of_prime_meridian" => 0.,
"semi_major_axis" => 6378137.,
"inverse_flattening" => 298.257223563 ,
"spatial_ref" => "PROJCS[\"WGS 84 / UTM zone 29N\",GEOGCS[\"WGS 84\",
DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,
AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],
PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],
UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],
AUTHORITY[\"EPSG\",\"4326\"]],
PROJECTION[\"Transverse_Mercator\"],
PARAMETER[\"latitude_of_origin\",0],
PARAMETER[\"central_meridian\",-9],
PARAMETER[\"scale_factor\",0.9996],
PARAMETER[\"false_easting\",500000],
PARAMETER[\"false_northing\",0],
UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],
AXIS[\"Easting\",EAST],
AXIS[\"Northing\",NORTH],
AUTHORITY[\"EPSG\",\"32629\"]]",
"GeoTransform" => "722576.2320803495 20 0 4115483.464603715 0 -20 ")

global const epsg4326=Dict(
  "grid_mapping_name" => "latitude_longitude",
  "long_name" => "CRS definition",
  "longitude_of_prime_meridian" => 0.,
  "semi_major_axis" => 6378137.,
  "inverse_flattening" => 298.257223563,
  "spatial_ref" => "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0],UNIT[\"degree\",0.0174532925199433],AUTHORITY[\"EPSG\",\"4326\"]]",
  "GeoTransform" => "-98.68712696894481 0.0001796630568239077 0 20.69179551612753 0 -0.0001796630568239077 "
)

end
