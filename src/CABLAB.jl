"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module CABLAB
export Cube, getCube,getTimeRanges,CubeMem

using DataStructures
using Base.Dates
using NullableArrays

type ConfigEntry{LHS}
    lhs
    rhs
end

include("axes.jl")

"
 A data cube's static configuration information.

 - `spatial_res`: The spatial image resolution in degree.
 - `grid_x0`: The fixed grid X offset (longitude direction).
 - `grid_y0`: The fixed grid Y offset (latitude direction).
 - `grid_width`: The fixed grid width in pixels (longitude direction).
 - `grid_height`: The fixed grid height in pixels (latitude direction).
 - `temporal_res`: The temporal resolution in days.
 - `ref_time`: A datetime value which defines the units in which time values are given, namely days since *ref_time*.
 - `start_time`: The start time of the first image of any variable in the cube given as datetime value.
                    ``None`` means unlimited.
 - `end_time`: The end time of the last image of any variable in the cube given as datetime value.
                  ``None`` means unlimited.
 - `variables`: A list of variable names to be included in the cube.
 - `file_format`: The file format used. Must be one of 'NETCDF4', 'NETCDF4_CLASSIC', 'NETCDF3_CLASSIC'
                     or 'NETCDF3_64BIT'.
 - `compression`: Whether the data should be compressed.
 "
type CubeConfig
    end_time::DateTime
    ref_time::DateTime
    start_time::DateTime
    grid_width::Int
    variables::Any
    temporal_res::Int
    grid_height::Int
    calendar::UTF8String
    file_format::UTF8String
    spatial_res::Float64
    model_version::UTF8String
    grid_y0::Int
    compression::Bool
    grid_x0::Int
end
t0=DateTime(0)
CubeConfig()=CubeConfig(t0,t0,t0,0,0,0,0,"","",0.0,"",0,false,0)

parseEntry(d,e::ConfigEntry)=setfield!(d,Symbol(e.lhs),parse(e.rhs))
parseEntry(d,e::ConfigEntry{:compression})=setfield!(d,Symbol(e.lhs),e.rhs=="False" ? false : true)
parseEntry(d,e::Union{ConfigEntry{:model_version},ConfigEntry{:file_format},ConfigEntry{:calendar}})=setfield!(d,Symbol(e.lhs),utf8(strip(e.rhs,'\'')))
function parseEntry(d,e::Union{ConfigEntry{:ref_time},ConfigEntry{:start_time},ConfigEntry{:end_time}})
    m=match(r"datetime.datetime\(\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)",e.rhs).captures
    setfield!(d,Symbol(e.lhs),DateTime(parse(Int,m[1]),parse(Int,m[2]),parse(Int,m[3]),parse(Int,m[4]),parse(Int,m[5])))
end

function parseConfig(cubepath)
  configfile=joinpath(cubepath,"cube.config")
  x=split(readchomp(configfile),"\n")
  d=CubeConfig()
  for ix in x
    s1,s2=split(ix,'=')
    s1=strip(s1);s2=strip(s2)
    e=ConfigEntry{symbol(s1)}(s1,s2)
    parseEntry(d,e)
  end
  d
end

"
Represents a data cube. The default constructor is

    Cube(base_dir)

where `base_dir` is the datacube's base directory.
"
type Cube
    base_dir::UTF8String
    config::CubeConfig
    dataset_files::Vector{UTF8String}
    var_name_to_var_index::OrderedDict{UTF8String,Int}
    firstYearOffset::Int
end
function Cube(base_dir::AbstractString)
  cubeconfig=parseConfig(base_dir)
  data_dir=joinpath(base_dir,"data")
  data_dir_entries=readdir(data_dir)
  sort!(data_dir_entries)
  var_name_to_var_index=OrderedDict{UTF8String,Int}()
  for i=1:length(data_dir_entries) var_name_to_var_index[data_dir_entries[i]]=i end
  firstYearOffset=div(dayofyear(cubeconfig.start_time)-1,cubeconfig.temporal_res)
  Cube(base_dir,cubeconfig,data_dir_entries,var_name_to_var_index,firstYearOffset)
end

type CubeMem{T,N} <: AbstractArray{T,N}
  axes::Vector{CubeAxis}
  data::Array{T,N}
  mask::Array{UInt8,N}
end

Base.linearindexing(::CubeMem)=Base.LinearFast()
Base.getindex(c::CubeMem,i::Integer)=getindex(c.data,i)
Base.setindex!(c::CubeMem,i::Integer,v)=setindex!(c.data,i,v)
Base.size(c::CubeMem)=size(c.data)
Base.similar(c::CubeMem)=cubeMem(c.lon,c.lat,c.time,similar(c.data))



"""

    getCube(cube::Cube;variable,time,latitude,longitude)

The following keyword arguments are accepted:

- *variable*: an variable index or name or an iterable returning multiple of these (var1, var2, ...)
- *time*: a single datetime.datetime object or a 2-element iterable (time_start, time_end)
- *latitude*: a single latitude value or a 2-element iterable (latitude_start, latitude_end)
- *longitude*: a single longitude value or a 2-element iterable (longitude_start, longitude_end)

Returns a dictionary mapping variable names --> arrays of dimension (longitude, latitude, time)

http://earthsystemdatacube.org
"""
function getCube(cube::Cube;variable=Int[],time=[],latitude=[],longitude=[])
    #First fill empty inputs
    isempty(variable) && (variable = defaultvariable(cube))
    isempty(time)     && (time     = defaulttime(cube))
    isempty(latitude) && (latitude = defaultlatitude(cube))
    isempty(longitude)&& (longitude= defaultlongitude(cube))
    getCube(cube,variable,time,latitude,longitude)
end

defaulttime(cube::Cube)=cube.config.start_time,cube.config.end_time-Day(1)
defaultvariable(cube::Cube)=cube.dataset_files
defaultlatitude(cube::Cube)=(-90.0,90.0)
defaultlongitude(cube::Cube)=(-180.0,180.0)

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

"Returns a vector of DateTime objects giving the time indices returned by a respective call to getCube."
function getTimeRanges(c::Cube,time::Tuple{Dates.TimeType,Dates.TimeType}=(cdata.cube.config.start_time,cdata.cube.config.end_time-Dates.Day(1)))
    NpY    = ceil(Int,365/c.config.temporal_res)
    yrange = Dates.year(time[1]):Dates.year(time[2])
    #TODO handle non-full year case properly
    reshape([DateTime(y)+Dates.Day((i-1)*c.config.temporal_res) for i=1:NpY, y=yrange],NpY*length(yrange))
end

#Convert single input to vectors
function getCube{T<:Union{Integer,AbstractString}}(cube::Cube,
                variable::Union{AbstractString,Integer,AbstractVector{T}},
                time::Union{Tuple{TimeType,TimeType},TimeType},
                latitude::Union{Tuple{Real,Real},Real},
                longitude::Union{Tuple{Real,Real},Real})

  isa(time,TimeType) && (time=(time,time))
  isa(latitude,Real) && (latitude=(latitude,latitude))
  isa(longitude,Real) && (longitude=(longitude,longitude))
  isa(variable,AbstractVector) && isa(eltype(variable),Integer) && (variable=[cube.config.dataset_files[i] for i in variable])
  isa(variable,Integer) && (variable=dataset_files[i])
  getCube(cube,variable,time,longitude,latitude)
end

function getCube{T<:AbstractString}(cube::Cube,
                variable::Vector{T},
                time::Tuple{TimeType,TimeType},
                latitude::Tuple{Real,Real},
                longitude::Tuple{Real,Real})
  r=Dict{T,Any}()
  for i=1:length(variable)
    if haskey(cube.var_name_to_var_index,variable[i])
      r[variable[i]]=getCube(cube,variable[i],time,latitude,longitude)
    else
      warn("Skipping variable $(variable[i]), not found in Datacube")
    end
  end
end

function getLonLatsToRead(config,longitude,latitude)
  grid_y1 = round(Int,(90.0 - latitude[2]) / config.spatial_res) - config.grid_y0 + 1
  grid_y2 = round(Int,(90.0 - latitude[1]) / config.spatial_res) - config.grid_y0
  grid_x1 = round(Int,(180.0 + longitude[1]) / config.spatial_res) - config.grid_x0 + 1
  grid_x2 = round(Int,(180.0 + longitude[2]) / config.spatial_res) - config.grid_x0
  grid_y1,grid_y2,grid_x1,grid_x2
end


function getCube(cube::Cube,
                variable::AbstractString,
                time::Tuple{TimeType,TimeType},
                latitude::Tuple{Real,Real},
                longitude::Tuple{Real,Real})
    # This function is doing the actual reading
    config=cube.config

    grid_y1,grid_y2,grid_x1,grid_x2 = getLonLatsToRead(config,longitude,latitude)
    y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)

    datafiles=sort!(readdir(joinpath(cube.base_dir,"data",variable)))
    fnamefirst=datafiles[1]
    v=NetCDF.open(joinpath(cube.base_dir,"data",variable,fnamefirst),variable)
    t=vartype(v)
    outar=Array(t,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)

    if y1==y2
        outar[:]=v[grid_x1:grid_x2,grid_y1:grid_y2,i1:i2]
        ncclose()
    else
        #Read from first year
        outar[:,:,1:(NpY-i1+1)]=v[grid_x1:grid_x2,grid_y1:grid_y2,i1:NpY]
        #Read full "sandwich" years
        ifirst=NpY-i1+2
        for y=(y1+1):(y2-1)
            v=NetCDF.open(joinpath(cube.base_dir,"data",variable,"$(y)_$(variable).nc"),variable)
            outar[:,:,ifirst:(ifirst+NpY-1)]=v[grid_x1:grid_x2,grid_y1:grid_y2,:]
            ifirst+=NpY
        end
        #Read from last Year
        v=NetCDF.open(joinpath(cube.base_dir,"data",variable,"$(y2)_$(variable).nc"),variable)
        outar[:,:,(end-i2+1):end]=v[grid_x1:grid_x2,grid_y1:grid_y2,1:i2]
        ncclose()
    end

    return CubeMem(CubeAxis[LonAxis(longitude[1]:0.25:longitude[2]),LatAxis(latitude[1]:0.25:latitude[2]),TimeAxis(getTimeRanges(cube,time))],outar,zeros(UInt8,size(outar)))
    #joinpath(cube.base_dir,"data",variable,"$(y1)_$(variable).nc")

end
end # module

include("DAT.jl")
