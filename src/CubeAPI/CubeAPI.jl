module CubeAPI
importall ..Cubes
importall ..Cubes.Axes
importall ..ESDLTools
import Base.Markdown.@md_str
export Cube, getCubeData,getTimeRanges,readCubeData, getMemHandle, RemoteCube, known_regions
export isvalid, isinvalid, isvalid, isvalidorfilled, Mask
export showVarInfo

include("Mask.jl")
include("countrydict.jl")
importall .Mask
using DataStructures
using Base.Dates
import Requests.get
import DataStructures.OrderedDict
using LightXML

type ConfigEntry{LHS}
  lhs
  rhs
end

#This is probably not the final solution, we define a set of static variables that are treated differently when reading
const static_vars = Set(["water_mask","country_mask","srex_mask"])
const countrylabels = include("countrylabels.jl")
const srexlabels = include("srexlabels.jl")
include("vardict.jl")
const known_labels = Dict("water_mask"=>Dict(0x01=>"land",0x02=>"water"),"country_mask"=>countrylabels,"srex_mask"=>srexlabels)
const known_names = Dict("water_mask"=>"Water","country_mask"=>"Country","srex_mask"=>"SREXregion")

"
A data cube's static configuration information.

* `spatial_res`: The spatial image resolution in degree.
* `grid_x0`: The fixed grid X offset (longitude direction).
* `grid_y0`: The fixed grid Y offset (latitude direction).
* `grid_width`: The fixed grid width in pixels (longitude direction).
* `grid_height`: The fixed grid height in pixels (latitude direction).
* `static_data`:
* `temporal_res`: The temporal resolution in days.
* `ref_time`: A Date value which defines the units in which time values are given, namely days since *ref_time*.
* `start_time`: The start time of the first image of any variable in the cube given as Date value.
``None`` means unlimited.
* `end_time`: The end time of the last image of any variable in the cube given as Date value.
``None`` means unlimited.
* `variables`: A list of variable names to be included in the cube.
* `file_format`: The file format used. Must be one of 'NETCDF4', 'NETCDF4_CLASSIC', 'NETCDF3_CLASSIC'
or 'NETCDF3_64BIT'.
* `compression`: Whether the data should be compressed.
"
type CubeConfig
  end_time::Date
  ref_time::Date
  start_time::Date
  grid_width::Int
  variables::Any
  temporal_res::Int
  grid_height::Int
  static_data::Bool
  calendar::String
  file_format::String
  spatial_res::Float64
  model_version::String
  grid_y0::Int
  compression::Bool
  grid_x0::Int
  chunk_sizes::Tuple{Int,Int,Int}
end
t0=Date(0)
CubeConfig()=CubeConfig(t0,t0,t0,0,0,0,0,false,"","",0.0,"",0,false,0,(0,0,0))

parseEntry(d,e::ConfigEntry)=setfield!(d,Symbol(e.lhs),parse(e.rhs))
parseEntry(d,e::Union{ConfigEntry{:compression},ConfigEntry{:static_data}})=setfield!(d,Symbol(e.lhs),e.rhs=="False" ? false : true)
parseEntry(d,e::Union{ConfigEntry{:model_version},ConfigEntry{:file_format},ConfigEntry{:calendar}})=setfield!(d,Symbol(e.lhs),String(strip(e.rhs,'\'')))
function parseEntry(d,e::Union{ConfigEntry{:ref_time},ConfigEntry{:start_time},ConfigEntry{:end_time}})
  m=match(r"datetime.datetime\(\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)",e.rhs).captures
  setfield!(d,Symbol(e.lhs),Date(parse(Int,m[1]),parse(Int,m[2]),parse(Int,m[3])))
end
function parseEntry(d,e::ConfigEntry{:chunk_sizes})
  p=parse(e.rhs).args
  d.chunk_sizes=(p[1],p[2],p[3])
end
function parseConfig(x)
  d=CubeConfig()
  for ix in x
    isempty(ix) && continue
    s1,s2=split(ix,'=')
    s1=strip(s1);s2=strip(s2)
    e=ConfigEntry{Symbol(s1)}(s1,s2)
    parseEntry(d,e)
  end
  d
end

"""
Represents a data cube accessible though the file system. The default constructor is

Cube(base_dir)

where `base_dir` is the datacube's base directory.

### Fields

* `base_dir` the cube parent directory
* `config` the cube's static configuration [CubeConfig](@ref)
* `dataset_files` a list of datasets in the cube
* `var_name_to_var_index` basically the inverse of `dataset_files`

"""
type Cube
  base_dir::String
  config::CubeConfig
  dataset_files::Vector{String}
  var_name_to_var_index::OrderedDict{String,Int}
end

function Cube(;resolution="low")
  try
    Cube(joinpath(ENV["ESDL_CUBEDIR"],"$(resolution)-res"))
  catch
    RemoteCube(resolution=resolution)
  end
end

function Cube(base_dir::AbstractString)
  configfile=joinpath(base_dir,"cube.config")
  x=split(readchomp(configfile),"\n")
  cubeconfig=parseConfig(x)
  data_dir=joinpath(base_dir,"data")
  data_dir_entries=readdir(data_dir)
  sort!(data_dir_entries)
  var_name_to_var_index=OrderedDict{String,Int}()
  for i=1:length(data_dir_entries) var_name_to_var_index[data_dir_entries[i]]=i end
  Cube(base_dir,cubeconfig,data_dir_entries,var_name_to_var_index)
end

"""
Represents a remote data cube accessible through THREDDS. The default constructor is

RemoteCube(base_url)

where `base_url` is the datacube's base url.

### Fields

* `base_url` the cube parent directory
* `var_name_to_var_index` basically the inverse of `dataset_files`
* `dataset_files` a list of datasets in the cube
* `dataset_paths` a list of urls pointing to the different data sets
* `config` the cube's static configuration [CubeConfig](@ref)

```@example
using ESDL
ds=remoteCube()
```

"""
type RemoteCube
  base_url::String
  var_name_to_var_index::OrderedDict{String,Int}
  dataset_files::Vector{String}
  dataset_paths::Vector{String}
  config::CubeConfig
end

function testDAP()
  conda_nc_config=joinpath(Pkg.dir("Conda"),"deps","usr","bin","nc-config")
  nc_config = isfile(conda_nc_config) ? conda_nc_config : "nc-config"
  if !success(pipeline(`which nc-config`, DevNull))
    warn("Could not test for DAP support. Data access might fail.")
    return true
  else
    return `$(nc_config) --has-dap` |> readstring |> chomp =="yes"
  end
end

function RemoteCube(;resolution="low",url="http://www.brockmann-consult.de/cablab-thredds/")
  testDAP() || error("NetCDF built without DAP support. Accessing remote cubes is not possible.")
  resExt=resolution == "low" ? "fileServer/datacube-low-res/cube.config" : "fileServer/datacube-high-res/cube.config"
  xconfig=split(readstring(get(string(url,resExt))),"\n")
  config=parseConfig(xconfig)
  res=get(string(url,"catalog.xml"))
  xmldoc=parse_string(readstring(res));
  xroot=root(xmldoc)
  datasets=get_elements_by_tagname(xroot,"dataset")
  ds=datasets[findfirst(map(x->startswith(lowercase(attribute(x,"name")),resolution),datasets))]
  files=String[]
  paths=String[]
  for c in child_elements(ds)  # c is an instance of XMLNode
    a=attributes_dict(c)
    varname=a["ID"]
    endswith(varname,"_low") && (varname=String(varname[1:end-4]))
    endswith(varname,"_high") && (varname=String(varname[1:end-5]))
    push!(files,varname)
    push!(paths,string(url,"dodsC/",a["urlPath"]))
  end
  vtoInd=OrderedDict(files[i]=>i for i=1:length(files))
  RemoteCube(url,vtoInd,files,paths,config)
end

function Base.show(io::IO,c::Cube)
  println(io,"ESDL data cube at ",c.base_dir)
  println(io,"Spatial resolution:  ",c.config.grid_width,"x",c.config.grid_height," at ",c.config.spatial_res," degrees.")
  println(io,"Temporal resolution: ",c.config.start_time," to ",c.config.end_time," at ",c.config.temporal_res,"daily time steps")
  print(  io,"Variables:           ")
  for v in c.dataset_files
    print(io,v," ")
  end
  println(io)
end

function Base.show(io::IO,c::RemoteCube)
  println(io,"Remote ESDL data cube at ",c.base_url)
  println(io,"Spatial resolution:  ",c.config.grid_width,"x",c.config.grid_height," at ",c.config.spatial_res," degrees.")
  println(io,"Temporal resolution: ",c.config.start_time," to ",c.config.end_time," at ",c.config.temporal_res,"daily time steps")
  print(  io,"Variables:           ")
  for v in c.dataset_files
    print(io,v," ")
  end
  println(io)
end
const UCube = Union{Cube,RemoteCube}

"""
    immutable SubCube{T,C} <: AbstractCubeData{T,4}

A view into the data cube of a single variable. Is the type returned by the `mapCube`
function.

### Fields

* `cube::C` Parent cube
* `variable` selected variable
* `sub_grid` representation of the subgrid indices
* `sub_times` representation of the selected time steps
* `lonAxis`
* `latAxis`
* `timeAxis`

"""
immutable SubCube{T,C} <: AbstractSubCube{T,3}
  cube::C #Parent cube
  variable::String #Variable
  sub_grid::Tuple{Int,Int,Int,Int} #grid_y1,grid_y2,grid_x1,grid_x2
  sub_times::NTuple{6,Int} #y1,i1,y2,i2,ntime,NpY
  lonAxis::LonAxis
  latAxis::LatAxis
  timeAxis::TimeAxis
  properties::Dict{String}
end
axes(s::SubCube)=CubeAxis[s.lonAxis,s.latAxis,s.timeAxis]


"""
    immutable SubCubePerm{T} <: AbstractCubeData{T,3}

Representation of a `SubCube` with perumted dimensions

### Fields

* `parent` Parent SubCube
* `perm` the permutation
* `iperm` the inverse permutation
"""
immutable SubCubePerm{T} <: AbstractSubCube{T,3}
  parent::SubCube{T}
  perm::Tuple{Int,Int,Int}
  iperm::Tuple{Int,Int,Int}
end
SubCubePerm(p::SubCube,perm::Tuple{Int,Int,Int})=SubCubePerm(p,perm,getiperm(perm))
axes(s::SubCubePerm)=CubeAxis[s.parent.lonAxis,s.parent.latAxis,s.parent.timeAxis][collect(s.perm)]

Base.eltype{T}(s::AbstractCubeData{T})=T
Base.ndims(s::Union{SubCube,SubCubePerm})=3
Base.size(s::SubCube)=(length(s.lonAxis),length(s.latAxis),length(s.timeAxis))
Base.size(s::SubCube,i)=(length(s.lonAxis),length(s.latAxis),length(s.timeAxis))[i]
Base.size(s::SubCubePerm)=(s.perm[1]==1 ? length(s.parent.lonAxis) : s.perm[1]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
s.perm[2]==1 ? length(s.parent.lonAxis) : s.perm[2]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
s.perm[3]==1 ? length(s.parent.lonAxis) : s.perm[3]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis))
Base.size(s::SubCubePerm,i)=(s.perm[1]==1 ? length(s.parent.lonAxis) : s.perm[1]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
s.perm[2]==1 ? length(s.parent.lonAxis) : s.perm[2]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
s.perm[3]==1 ? length(s.parent.lonAxis) : s.perm[3]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis))[i]



"""
    immutable SubCubeV{T, C} <: AbstractCubeData{T,4}

A view into the data cube with multiple variables. Returned by the `mapCube`
function.

### Fields

* `cube::C` Parent cube
* `variable` list of selected variables
* `sub_grid` representation of the subgrid indices
* `sub_times` representation of the selected time steps
* `lonAxis`
* `latAxis`
* `timeAxis`
* `varAxis`

"""
immutable SubCubeV{T,C} <: AbstractSubCube{T,4}
  cube::C #Parent cube
  variable::Vector{String} #Variable
  sub_grid::Tuple{Int,Int,Int,Int} #grid_y1,grid_y2,grid_x1,grid_x2
  sub_times::NTuple{6,Int} #y1,i1,y2,i2,ntime,NpY
  lonAxis::LonAxis
  latAxis::LatAxis
  timeAxis::TimeAxis
  varAxis::VariableAxis
  properties::Dict{String}
end

"""
    immutable SubCubeVPerm{T} <: AbstractCubeData{T,4}

Representation of a `SubCubeV` with permuted dimensions.
"""
immutable SubCubeVPerm{T} <: AbstractSubCube{T,4}
  parent::SubCubeV{T}
  perm::NTuple{4,Int}
  iperm::NTuple{4,Int}
end
SubCubeVPerm{T}(p::SubCubeV{T},perm::Tuple{Int,Int,Int,Int})=SubCubeVPerm{T}(p,perm,getiperm(perm))
axes(s::SubCubeV)=CubeAxis[s.lonAxis,s.latAxis,s.timeAxis,s.varAxis]
axes(s::SubCubeVPerm)=CubeAxis[s.parent.lonAxis,s.parent.latAxis,s.parent.timeAxis,s.parent.varAxis][collect(s.perm)]
Base.ndims(s::SubCubeV)=4
Base.ndims(s::SubCubeVPerm)=4
Base.size(s::SubCubeV)=(length(s.lonAxis),length(s.latAxis),length(s.timeAxis),length(s.varAxis))
Base.size(s::SubCubeVPerm)=(s.perm[1]==1 ? length(s.parent.lonAxis) : s.perm[1]==2 ? length(s.parent.latAxis) : s.perm[1]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[2]==1 ? length(s.parent.lonAxis) : s.perm[2]==2 ? length(s.parent.latAxis) : s.perm[2]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[3]==1 ? length(s.parent.lonAxis) : s.perm[3]==2 ? length(s.parent.latAxis) : s.perm[3]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[4]==1 ? length(s.parent.lonAxis) : s.perm[4]==2 ? length(s.parent.latAxis) : s.perm[4]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis))
Base.size(s::SubCubeV,i)=(length(s.lonAxis),length(s.latAxis),length(s.timeAxis),length(s.varAxis))[i]
Base.size(s::SubCubeVPerm,i)=(s.perm[1]==1 ? length(s.parent.lonAxis) : s.perm[1]==2 ? length(s.parent.latAxis) : s.perm[1]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[2]==1 ? length(s.parent.lonAxis) : s.perm[2]==2 ? length(s.parent.latAxis) : s.perm[2]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[3]==1 ? length(s.parent.lonAxis) : s.perm[3]==2 ? length(s.parent.latAxis) : s.perm[3]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis),
s.perm[4]==1 ? length(s.parent.lonAxis) : s.perm[4]==2 ? length(s.parent.latAxis) : s.perm[4]==3 ? length(s.parent.timeAxis) : length(s.parent.varAxis))[i]

Base.permutedims{T}(c::SubCube{T},perm::NTuple{3,Int})=SubCubePerm(c,perm)
Base.permutedims{T}(c::SubCubeV{T},perm::NTuple{4,Int})=SubCubeVPerm(c,perm)

"""
    immutable SubCubeStatic{T, C} <: AbstractCubeData{T,2}

A view into the data cube with a single static variable. Returned by the `mapCube`
function.

### Fields

* `cube::C` Parent cube
* `variable` list of selected variables
* `sub_grid` representation of the subgrid indices
* `time` representation of the selected time steps
* `lonAxis`
* `latAxis`

"""
immutable SubCubeStatic{T,C} <: AbstractSubCube{T,2}
  cube::C #Parent cube
  variable::String #Variable
  sub_grid::Tuple{Int,Int,Int,Int} #grid_y1,grid_y2,grid_x1,grid_x2
  sub_times::NTuple{6,Int} #y1,i1,y2,i2,ntime,NpY
  lonAxis::LonAxis
  latAxis::LatAxis
  properties::Dict{String}
end

"""
    immutable SubCubeStaticPerm{T} <: AbstractCubeData{T,2}

Representation of a `SubCubeStatic` with permuted dimensions.
"""
immutable SubCubeStaticPerm{T} <: AbstractSubCube{T,2}
  parent::SubCubeV{T}
end
SubCubeStaticPerm{T}(p::SubCubeStatic{T})=SubCubeVPerm{T}(p)
axes(s::SubCubeStatic)=CubeAxis[s.lonAxis,s.latAxis]
axes(s::SubCubeStaticPerm)=CubeAxis[s.parent.latAxis,s.parent.lonAxis]
Base.ndims(s::SubCubeStatic)=2
Base.ndims(s::SubCubeStaticPerm)=2
Base.size(s::SubCubeStatic)=(length(s.lonAxis),length(s.latAxis))
Base.size(s::SubCubeStaticPerm)=(length(s.latAxis),length(s.lonAxis))
Base.size(s::SubCubeStatic,i)=(length(s.lonAxis),length(s.latAxis))[i]
Base.size(s::SubCubeStaticPerm,i)=(length(s.latAxis),length(s.lonAxis))[i]

sgetperm(s::Union{SubCubePerm,SubCubeVPerm})=s.perm
sgetiperm(s::Union{SubCubePerm,SubCubeVPerm})=s.iperm
getperm(s::SubCubeStaticPerm)=(2,1)
getiperm(s::SubCubeStaticPerm)=(2,1)
Base.permutedims{T}(c::SubCubeStatic{T},perm::NTuple{2,Int})=perm==(2,1) ? SubCubeStaticPerm(c) : error("There is only one permutation of a lon-lat cube, so perm must be (2,1)")


"""

getCubeData(cube::Cube;variable,time,latitude,longitude)

Returns a view into the data cube. The following keyword arguments are accepted:

- *variable*: an variable index or name or an iterable returning multiple of these (var1, var2, ...)
- *time*: a single Date object or a 2-element iterable (time_start, time_end)
- *latitude*: a single latitude value or a 2-element iterable (latitude_start, latitude_end)
- *longitude*: a single longitude value or a 2-element iterable (longitude_start, longitude_end)
- *region*: specify a country or SREX region by name or ISO_A3 code. Type `?ESDL.known_regions` to see a list of pre-defined areas

Returns a `SubCube` object which represents a view into the original data cube.


"""
function getCubeData(cube::UCube;variable=Int[],time=[],latitude=[],longitude=[],region=[])
  #First fill empty inputs
  isempty(variable)  && (variable = defaultvariable(cube))
  variable = expandknownvars(variable)
  time==Int[]        && (time     = defaulttime(cube,variable))
  if !isempty(region)
    haskey(known_regions,region) || error("Region $region not recognized as a known place")
    ll = known_regions[region]
    longitude = (ll[1],ll[3])
    latitude  = (ll[2],ll[4])
  end
  isempty(latitude)  && (latitude = defaultlatitude(cube))
  isempty(longitude) && (longitude= defaultlongitude(cube))
  getCubeData(cube,variable,time,longitude,latitude)
end

defaulttime(cube::UCube,v)=all_mask(v) ? cube.config.start_time : (cube.config.start_time,cube.config.end_time-Day(1))
defaultvariable(cube::UCube)=filter(i->i ∉ static_vars,cube.dataset_files)
defaultlatitude(cube::UCube)=(90.0-cube.config.grid_y0*cube.config.spatial_res,90.0-(cube.config.grid_y0+cube.config.grid_height)*cube.config.spatial_res)
defaultlongitude(cube::UCube)=(-180.0+cube.config.grid_x0*cube.config.spatial_res,-180.0+(cube.config.grid_x0+cube.config.grid_width)*cube.config.spatial_res)
all_mask(x::String)=x ∈ static_vars
all_mask(x::Vector{String})=all(all_mask,x)

using NetCDF
vartype{T,N}(v::NcVar{T,N})=T
"Function to get the years and times to read from user input."
function getTimesToRead(time1,time2,config)
  NpY    = ceil(Int,365/config.temporal_res)
  y1     = year(time1)
  y2     = year(time2)
  d1     = dayofyear(time1)
  index1 = round(Int,d1/config.temporal_res)+1
  d2     = dayofyear(time2)
  index2 = min(round(Int,d2/config.temporal_res)+1,NpY)
  ntimesteps = -index1 + index2 + (y2-y1)*NpY + 1
  return y1,index1,y2,index2,ntimesteps,NpY
end

"Returns a vector of Date objects giving the time indices returned by a respective call to getCubeData."
function getTimeRanges(c::UCube,y1,y2,i1,i2)
  NpY    = ceil(Int,365/c.config.temporal_res)
  YearStepRange(y1,i1,y2,i2,c.config.temporal_res,NpY)
end

#Convert single input to vectors
function getCubeData(cube::UCube,
  variable,
  time,
  longitude,
  latitude)

  isa(time,TimeType) && (time=(time,time))
  isa(latitude,Real) && (latitude=(latitude,latitude))
  isa(longitude,Real) && (longitude=(longitude,longitude))
  !isa(variable,Vector) && (variable=[variable])
  isa(eltype(variable),Integer) && (variable=[cube.config.dataset_files[i] for i in variable])
  getCubeData(cube,variable,time,longitude,latitude)
end

x2lon(x,config)   = (x+config.grid_x0-0.5)*config.spatial_res - 180.0
lon2x(lon,config) = round(Int,(180.0 + lon) / config.spatial_res - 0.5) - config.grid_x0
y2lat(y,config)   = 90.0 - (y+config.grid_y0-0.5)*config.spatial_res
lat2y(lat,config) = round(Int,(90.0 - lat) / config.spatial_res - 0.5) - config.grid_y0

function getLonLatsToRead(config,longitude,latitude)
  grid_y1 = lat2y(latitude[2],config) + 1
  grid_y2 = lat2y(latitude[1],config)
  grid_x1 = lon2x(longitude[1],config) + 1
  grid_x2 = lon2x(longitude[2],config)
  grid_x1==grid_x2+1 && (grid_x2+=1)
  grid_y1==grid_y2+1 && (grid_y2+=1)
  grid_y1,grid_y2,grid_x1,grid_x2
end

function getMaskFile(cube::Cube)
  filename=joinpath(cube.base_dir,"data","water_mask","2001_water_mask.nc")
  isfile(filename) && return(filename)
  return ""
end
function getMaskFile(cube::RemoteCube)

  filename=cube.config.spatial_res==0.25 ? string(cube.base_url,"dodsC/datasetRoot-low-res/data/water_mask/2001_water_mask.nc") : string(cube.base_url,"dodsC/datasetRoot-high-res/data/water_mask/2001_water_mask.nc")
  try
    nc=NetCDF.open(filename)
    NetCDF.close(nc)
    return filename
  catch
    return ""
  end
end

getLandSeaMask!(mask::AbstractArray{UInt8,2},cube::UCube,grid_x1,nx,grid_y1,ny)=getLandSeaMask!(reshape(mask,(size(mask,1),size(mask,2),1)),cube,grid_x1,nx,grid_y1,ny)
function getLandSeaMask!(mask::AbstractArray{UInt8,3},cube::UCube,grid_x1,nx,grid_y1,ny)
  filename=getMaskFile(cube)
  if !isempty(filename)
    mask2 = ncread(filename,"water_mask",start=[grid_x1,grid_y1,1],count=[nx,ny,1])
    mask[:,:,1]=mask2
    for ilat=1:size(mask,2),ilon=1:size(mask,1)
      mask[ilon,ilat,1]=(mask[ilon,ilat,1]-0x01)*0x05
    end
    nT=size(mask,3)
    for itime=2:nT,ilat=1:size(mask,2),ilon=1:size(mask,1)
      mask[ilon,ilat,itime]=mask[ilon,ilat,1]
    end
    ncclose(filename)
  end
end

function getLandSeaMask!(mask::AbstractArray{UInt8,4},cube::UCube,grid_x1,nx,grid_y1,ny)
  filename=filename=getMaskFile(cube)
  if !isempty(filename)
    mask2 = ncread(filename,"water_mask",start=[grid_x1,grid_y1,1],count=[nx,ny,1])
    mask[:,:,1,1]=mask2
    for ilat=1:size(mask,2),ilon=1:size(mask,1)
      mask[ilon,ilat,1]=(mask[ilon,ilat,1]-0x01)*0x05
    end
    nT=size(mask,3)
    for ivar=1:size(mask,4),itime=1:nT,ilat=1:size(mask,2),ilon=1:size(mask,1)
      mask[ilon,ilat,itime,ivar]=mask[ilon,ilat,1,1]
    end
    ncclose(filename)
  end
end

function getvartype(cube::Cube,variable)
  datafiles=sort!(readdir(joinpath(cube.base_dir,"data",variable)))
  eltype(NetCDF.open(joinpath(cube.base_dir,"data",variable,datafiles[1]),variable))
end

function getvartype(cube::RemoteCube,variable)
  datafile=cube.dataset_paths[cube.var_name_to_var_index[variable]]
  eltype(NetCDF.open(datafile,variable))
end

function expandknownvars{T}(v::Array{T})
  vnew = T[]
  for iv in v
    if haskey(known_vargroups,iv)
      for iiv in known_vargroups[iv]
        push!(vnew,iiv)
      end
    else
      push!(vnew,iv)
    end
  end
  vnew
end
expandknownvars(v::String)=expandknownvars([v])

ismiss(k::Integer)=(k==typemax(k))
ismiss(k::AbstractFloat)=isnan(k)

function getCubeData{T<:AbstractString}(cube::UCube,
  variable::Vector{T},
  time::Tuple{TimeType,TimeType},
  longitude::Tuple{Real,Real},
  latitude::Tuple{Real,Real})

  variable = expandknownvars(variable)

  config=cube.config

  longitude[1]>longitude[2] && throw(ArgumentError("Longitudes $longitude must be passed in West-to-East order."))

  latitude[1]>latitude[2] && (latitude=(latitude[2],latitude[1]))

  grid_y1,grid_y2,grid_x1,grid_x2 = getLonLatsToRead(config,longitude,latitude)
  y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)

  variableNew=String[]
  varTypes=DataType[]
  for i=1:length(variable)
    if haskey(cube.var_name_to_var_index,variable[i])
      t=getvartype(cube,variable[i])
      push!(variableNew,variable[i])
      push!(varTypes,t)
    else
      warn("Skipping variable $(variable[i]), not found in Datacube")
    end
  end
  t=reduce(promote_type,varTypes[1],varTypes)
  properties=Dict{String,Any}()
  if length(variableNew)==1
    if time[1]==time[2]
      # This is a static cube and probably small enough to be in memory
      c=SubCubeStatic{t,typeof(cube)}(cube,variable[1],
        (grid_y1,grid_y2,grid_x1,grid_x2),
        (y1,i1,y2,i2,ntime,NpY),
                LonAxis(x2lon(grid_x1,config):config.spatial_res:x2lon(grid_x2,config)+0.1*config.spatial_res),
                LatAxis(y2lat(grid_y1,config):-config.spatial_res:y2lat(grid_y2,config)-0.1*config.spatial_res),
        properties)
      d=readCubeData(c)
      if haskey(known_labels,variable[1])
        rem_keys = unique(d.data)
        all_labels = known_labels[variable[1]]
        left_labels = OrderedDict((k,all_labels[k]) for k in rem_keys if !ismiss(k))
        d.properties["labels"]=left_labels
        d.properties["name"]=known_names[variable[1]]
      end
      return d
    else
      return SubCube{t,typeof(cube)}(cube,variable[1],
        (grid_y1,grid_y2,grid_x1,grid_x2),
        (y1,i1,y2,i2,ntime,NpY),
        LonAxis(x2lon(grid_x1,config):config.spatial_res:x2lon(grid_x2,config)+0.1*config.spatial_res),
        LatAxis(y2lat(grid_y1,config):-config.spatial_res:y2lat(grid_y2,config)-0.1*config.spatial_res),
        TimeAxis(getTimeRanges(cube,y1,y2,i1,i2)),
        properties)
    end
  else
    return SubCubeV{t,typeof(cube)}(cube,variable,
      (grid_y1,grid_y2,grid_x1,grid_x2),
      (y1,i1,y2,i2,ntime,NpY),
      LonAxis(x2lon(grid_x1,config):config.spatial_res:x2lon(grid_x2,config)+0.1*config.spatial_res),
      LatAxis(y2lat(grid_y1,config):-config.spatial_res:y2lat(grid_y2,config)-0.1*config.spatial_res),
      TimeAxis(getTimeRanges(cube,y1,y2,i1,i2)),
      VariableAxis(variableNew),
      properties)
  end
end

function readCubeData{T}(s::SubCube{T})
  grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
  y1,i1,y2,i2,ntime,NpY           = s.sub_times
  outar=Array{T}(grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)
  mask=zeros(UInt8,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)
  _read(s,(outar,mask),CartesianRange((grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)))
  return CubeMem(CubeAxis[s.lonAxis,s.latAxis,s.timeAxis],outar,mask)
end

function readCubeData{T}(s::SubCubeV{T})
  grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
  y1,i1,y2,i2,ntime,NpY           = s.sub_times
  outar=Array{T}(grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))
  mask=zeros(UInt8,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))
  _read(s,(outar,mask),CartesianRange((grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))))
  return CubeMem(CubeAxis[s.lonAxis,s.latAxis,s.timeAxis,s.varAxis],outar,mask)
end

function readCubeData{T}(s::SubCubeStatic{T})
  grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
  y1,i1,y2,i2,ntime,NpY           = s.sub_times
  outar=Array{T}(grid_x2-grid_x1+1,grid_y2-grid_y1+1)
  mask=zeros(UInt8,grid_x2-grid_x1+1,grid_y2-grid_y1+1)
  _read(s,(reshape(outar,(size(outar,1),size(outar,2),1)),reshape(mask,(size(mask,1),size(mask,2),1))),CartesianRange((grid_x2-grid_x1+1,grid_y2-grid_y1+1,1)))
  return CubeMem(CubeAxis[s.lonAxis,s.latAxis],outar,mask)
end

"""
Add a function to read some CubeData in a permuted way, we will make a copy here for simplicity, however, this might change in the future
"""
function _read{T,N}(s::Union{SubCubeVPerm{T},SubCubePerm{T},SubCubeStaticPerm{T}},t::Tuple,r::CartesianRange{CartesianIndex{N}})  #;xoffs::Int=0,yoffs::Int=0,toffs::Int=0,voffs::Int=0,nx::Int=size(outar,findin(s.perm,1)[1]),ny::Int=size(outar,findin(s.perm,2)[1]),nt::Int=size(outar,findin(s.perm,3)[1]),nv::Int=size(outar,findin(s.perm,4)[1]))
  iperm=sgetiperm(s)
  perm=sgetperm(s)
  outar,mask=t
  sout=map(-,r.stop.I,(r.start-CartesianIndex{N}()).I)[iperm]
  #println("xoffs=$xoffs yoffs=$yoffs toffs=$toffs voffs=$voffs nx=$nx ny=$ny nt=$nt nv=$nv")
  outartemp=Array{T}(sout...)
  masktemp=zeros(UInt8,sout...)
  _read(s.parent,(outartemp,masktemp),CartesianRange(CartesianIndex(r.start.I[iperm]),CartesianIndex(r.stop.I[iperm])))
  mypermutedims!(outar,outartemp,Val{perm})
  mypermutedims!(mask,masktemp,Val{perm})
end

getNv(r::CartesianRange{CartesianIndex{2}})=(0,1)
getNv(r::CartesianRange{CartesianIndex{3}})=(0,1)
getNv(r::CartesianRange{CartesianIndex{4}})=(r.start.I[4]-1,r.stop.I[4]-r.start.I[4]+1)

function readAllyears{T}(s::SubCube{T,RemoteCube},outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
  tstart  = (y1 - year(s.cube.config.start_time))*NpY + i1
  readRemote(s.cube,outar,mask,s.variable,grid_x1,nx,grid_y1,ny,tstart,nt)
end

function readAllyears{T}(s::SubCubeStatic{T,RemoteCube},outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
  tstart  = (y1 - year(s.cube.config.start_time))*NpY + i1
  readRemote(s.cube,reshape(outar,(size(outar,1),size(outar,2),1)),reshape(mask,(size(mask,1),size(mask,2),1)),s.variable,grid_x1,nx,grid_y1,ny,tstart,1)
end

function readAllyears{T}(s::SubCubeV{T,RemoteCube},outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
  tstart  = (y1 - year(s.cube.config.start_time))*NpY + i1
  for iv in (voffs+1):(nv+voffs)
    outar2=view(outar,:,:,:,iv-voffs)
    mask2=view(mask,:,:,:,iv-voffs)
    readRemote(s.cube,outar2,mask2,s.variable[iv],grid_x1,nx,grid_y1,ny,tstart,nt)
  end
end


function readRemote{T}(cube::RemoteCube,outar::AbstractArray{T,3},mask::AbstractArray{UInt8,3},variable,grid_x1,nx,grid_y1,ny,tstart,nt)
  @assert size(outar)==(nx,ny,nt)
  filename=cube.dataset_paths[cube.var_name_to_var_index[variable]]
  #xr = grid_x1:(grid_x1+nx-1)
  #yr = grid_y1:(grid_y1+ny-1)
  #tr = tstart:(tstart+nt-1)
  nanval=convert(T,NaN)
  #Make some assertions for inbounds
  @assert tstart>0
  @assert nt==size(outar,3)
  @assert ny==size(outar,2)
  @assert nx==size(outar,1)
  @assert size(outar)==size(mask)
  v=try
    NetCDF.open(filename,variable);
  catch
    mask[:]  = OUTOFPERIOD
    outar[:] = nanval
    return false
  end
  scalefac::T = convert(T,get(v.atts,"scale_factor",one(T)))
  offset::T   = convert(T,get(v.atts,"add_offset",zero(T)))
  NetCDF.readvar!(v,outar,start=[grid_x1,grid_y1,tstart],count=[nx,ny,nt])
  missval::T=convert(T,ncgetatt(filename,variable,"_FillValue"))
  @inbounds for i in eachindex(outar)
    if (outar[i] == missval) || isnan(outar[i])
      mask[i]  = MISSING
      outar[i] = nanval
    else
      outar[i]=outar[i]*scalefac+offset
    end
  end
  ncclose(filename)
  return true
end

gettoffsnt(::AbstractSubCube,r::CartesianRange)=(r.start.I[3] - 1,r.stop.I[3]  - r.start.I[3]+1)
gettoffsnt(::SubCubeStatic,r::CartesianRange{CartesianIndex{2}})=(0,1)

  function _read(s::AbstractSubCube,t::Tuple,r::CartesianRange) #;xoffs::Int=0,yoffs::Int=0,toffs::Int=0,voffs::Int=0,nx::Int=size(outar,1),ny::Int=size(outar,2),nt::Int=size(outar,3),nv::Int=length(s.variable))

    outar,mask=t
    grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
    y1,i1,y2,i2,ntime,NpY           = s.sub_times

    grid_x1 = grid_x1 + r.start.I[1] - 1
    nx      = r.stop.I[1] - r.start.I[1] + 1
    grid_y1 = grid_y1 + r.start.I[2] - 1
    ny      = r.stop.I[2] - r.start.I[2] +1
    toffs,nt= gettoffsnt(s,r)
    if toffs > 0
      i1 = i1 + toffs
      if i1 > NpY
        y1 = y1 + div(i1-1,NpY)
        i1 = mod(i1-1,NpY)+1
      end
    end

    #println("Year 1=",y1)
    #println("i1    =",i1)
    #println("grid_x=",grid_x1:(grid_x1+nx-1))
    #println("grid_y=",grid_y1:(grid_y1+ny-1))
    #println("arsize=",size(mask))

    voffs,nv = getNv(r)

    fill!(mask,zero(UInt8))
    getLandSeaMask!(mask,s.cube,grid_x1,nx,grid_y1,ny)

    readAllyears(s,outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
  end

  function readAllyears(s::SubCube,outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
    ycur=y1   #Current year to read
    i1cur=i1  #Current time step in year
    itcur=1   #Current time step in output file
    fin = false
    while !fin
      fin,ycur,i1cur,itcur = readFromDataYear(s.cube,outar,mask,s.variable,ycur,grid_x1,nx,grid_y1,ny,itcur,i1cur,nt,NpY)
    end
  end

  function readAllyears(s::SubCubeStatic,outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
    ycur=y1   #Current year to read
    i1cur=i1  #Current time step in year
    itcur=1   #Current time step in output file
    fin = false
    while !fin
      fin,ycur,i1cur,itcur = readFromDataYear(s.cube,reshape(outar,(size(outar,1),size(outar,2),1)),reshape(mask,(size(mask,1),size(mask,2),1)),s.variable,ycur,grid_x1,nx,grid_y1,ny,itcur,i1cur,nt,NpY)
    end
  end

  function readAllyears(s::SubCubeV,outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
    for iv in (voffs+1):(nv+voffs)
      outar2=view(outar,:,:,:,iv-voffs)
      mask2=view(mask,:,:,:,iv-voffs)
      ycur=y1   #Current year to read
      i1cur=i1  #Current time step in year
      itcur=1   #Current time step in output file
      fin = false
      while !fin
        fin,ycur,i1cur,itcur = readFromDataYear(s.cube,outar2,mask2,s.variable[iv],ycur,grid_x1,nx,grid_y1,ny,itcur,i1cur,nt,NpY)
      end
    end
  end


immutable ESDLVarInfo
  longname::String
  units::String
  url::String
  comment::String
  reference::String
end

getremFileName(cube::RemoteCube,variable::String)=cube.dataset_paths[cube.var_name_to_var_index[variable]][1]
function getremFileName(cube::Cube,variable::String)
    filepath=joinpath(cube.base_dir,"data",variable)
    filelist=readdir(filepath)
    isempty(filelist) && error("Could not retrieve METADATA for variable $variable")
    return joinpath(filepath,filelist[1])
end

showVarInfo(cube::SubCube)=showVarInfo(cube,cube.variable)
showVarInfo(cube::SubCubeStatic)=showVarInfo(cube,cube.variable)
showVarInfo(cube::SubCubeV)=[showVarInfo(cube,v) for v in cube.variable]
function showVarInfo(cube, variable::String)
    filename=getremFileName(cube.cube,variable)
    v=NetCDF.open(filename,variable)
    vi=ESDLVarInfo(
      get(v.atts,"long_name",variable),
      get(v.atts,"units","unknown"),
      get(v.atts,"url","no link"),
      get(v.atts,"comment",variable),
      get(v.atts,"references","no reference")
    )
    ncclose(filename)
    return vi
end

import Base.show
function show(io::IO,::MIME"text/markdown",v::ESDLVarInfo)
    un=v.units
    url=v.url
    re=v.reference
    mdt=md"""
### $(v.longname)
*$(v.comment)*

* **units** $un
* **Link** $url
* **Reference** $re
"""
    mdt[3].items[1][1].content[3]=[" $un"]
    mdt[3].items[2][1].content[3]=[" [$url]"]
    mdt[3].items[3][1].content[3]=[" $re"]
    show(io,MIME"text/markdown"(),mdt)
end
show(io::IO,::MIME"text/markdown",v::Vector{ESDLVarInfo})=foreach(x->show(io,MIME"text/markdown"(),x),v)


getNanVal{T<:AbstractFloat}(::Type{T}) = convert(T,NaN)
getNanVal{T<:Integer}(::Type{T})       = typemax(T)

function readFromDataYear{T}(cube::Cube,outar::AbstractArray{T,3},mask::AbstractArray{UInt8,3},variable,y,grid_x1,nx,grid_y1,ny,itcur,i1cur,ntime,NpY)
  filename=joinpath(cube.base_dir,"data",variable,string(y,"_",variable,".nc"))
  ntleft = ntime - itcur + 1
  nt = min(NpY-i1cur+1,ntleft)
  xr = grid_x1:(grid_x1+nx-1)
  yr = grid_y1:(grid_y1+ny-1)
  nanval=getNanVal(T)
  #Make some assertions for inbounds
  @assert itcur>0
  @assert (itcur+nt-1)<=size(outar,3)
  @assert ny==size(outar,2)
  @assert nx==size(outar,1)
  @assert size(outar)==size(mask)
  if isfile(filename)
    v=convert(NcVar{T},NetCDF.open(filename,variable))
    scalefac::T = convert(T,get(v.atts,"scale_factor",one(T)))
    offset::T   = convert(T,get(v.atts,"add_offset",zero(T)))
    NetCDF.readvar!(v,view(outar,:,:,itcur:(itcur+nt-1)),start=[grid_x1,grid_y1,i1cur],count=[nx,ny,nt])
    missval::T=convert(T,ncgetatt(filename,variable,"_FillValue"))
    @inbounds for k=itcur:(itcur+nt-1),j=1:ny,i=1:nx
      if (outar[i,j,k] == missval) || isnan(outar[i,j,k])
        mask[i,j,k]=mask[i,j,k] | MISSING
        outar[i,j,k]=nanval
      else
        outar[i,j,k]=outar[i,j,k]*scalefac+offset
      end
    end
    ncclose(filename)
    else
      @inbounds for k=itcur:(itcur+nt-1),j=1:ny,i=1:nx
        mask[i,j,k]=(mask[i,j,k] | OUTOFPERIOD)
        outar[i,j,k]=nanval
      end
    end
    itcur+=nt
    y+=1
    i1cur=1
    fin=nt==ntleft
    return fin,y,i1cur,itcur
  end

  include("CachedArrays.jl")
  importall .CachedArrays

  function getMemHandle{T}(cube::AbstractCubeData{T},nblock,block_size;startInd::Int=1)
    CachedArray(cube,nblock,block_size,CachedArrays.MaskedCacheBlock{T,length(block_size)},startInd=startInd)
  end
  getMemHandle(cube::AbstractCubeMem,nblock,block_size;startInd::Int=1)=cube


end
