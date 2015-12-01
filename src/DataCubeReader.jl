module DataCubeReader
export Cube, CubeData, getCube

using DataStructures
using Base.Dates

type ConfigEntry{LHS}
    lhs
    rhs
end
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

type Cube
    base_dir::UTF8String
    config::CubeConfig
end
Cube(base_dir::AbstractString)=Cube(base_dir,parseConfig(base_dir))

type CubeData
    cube::Cube
    dataset_files::Vector{UTF8String}
    var_name_to_var_index::OrderedDict{UTF8String,Int}
    firstYearOffset::Int
end
function CubeData(cube::Cube)
    data_dir=joinpath(cube.base_dir,"data")
    data_dir_entries=readdir(data_dir)
    sort!(data_dir_entries)
    var_name_to_var_index=OrderedDict{UTF8String,Int}()
    for i=1:length(data_dir_entries) var_name_to_var_index[data_dir_entries[i]]=i end
    firstYearOffset=div(dayofyear(cube.config.start_time)-1,cube.config.temporal_res)
    CubeData(cube,data_dir_entries,var_name_to_var_index,firstYearOffset)
end

function getCube(cubedata::CubeData;variable=Int[],time=[],latitude=[],longitude=[])
    #First fill empty inputs
    isempty(variable) && (variable = cubedata.dataset_files)
    isempty(time)     && (time     = (cubedata.cube.config["start_time"],cubedata.cube.config["end_time"]))
    isempty(latitude) && (latitude = (-90,90))
    isempty(longitude)&& (longitude= (-180,180))
    get(cubedata,variable,time,latitude,longitude)
end

using NetCDF
vartype{T,N}(v::NcVar{T,N})=T
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

function getCube(cubedata::CubeData,
                variable::AbstractString,
                time::Tuple{TimeType,TimeType},
                latitude::Tuple{Real,Real},
                longitude::Tuple{Real,Real})
    # This function is doing the actual reading
    config=cubedata.cube.config
    grid_y1 = round(Int,(90.0 - latitude[2]) / config.spatial_res) - config.grid_y0 + 1
    grid_y2 = round(Int,(90.0 - latitude[1]) / config.spatial_res) - config.grid_y0
    grid_x1 = round(Int,(180.0 + longitude[1]) / config.spatial_res) - config.grid_x0 + 1
    grid_x2 = round(Int,(180.0 + longitude[2]) / config.spatial_res) - config.grid_x0

    y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)

    v=NetCDF.open(joinpath(cubedata.cube.base_dir,"data",variable,"$(y1)_$(variable).nc"),variable)
    t=vartype(v)

    if y1==y2
        return(v[grid_x1:grid_x2,grid_y1:grid_y2,i1:i2])
    else
        #Allocate Space
        outar=zeros(grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)
        #Read from first year
        outar[:,:,1:(NpY-i1+1)]=v[grid_x1:grid_x2,grid_y1:grid_y2,i1:NpY]
        #Read full "sandwich" years
        ifirst=NpY-i1+2
        for y=(y1+1):(y2-1)
            outar[:,:,ifirst:(ifirst+NpY-1)]=v[grid_x1:grid_x2,grid_y1:grid_y2,:]
            ifirst+=NpY
        end
        #Read from last Year
        outar[:,:,(end-i2+1):end]=v[grid_x1:grid_x2,grid_y1:grid_y2,1:i2]
        return outar
    end
    #joinpath(cubedata.cube.base_dir,"data",variable,"$(y1)_$(variable).nc")

end
end # module
