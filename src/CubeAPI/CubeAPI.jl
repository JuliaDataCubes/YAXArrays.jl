module CubeAPI
importall ..Cubes
importall ..Cubes.Axes
importall ..CABLABTools
export Cube, getCubeData,getTimeRanges,readCubeData, getMemHandle
export VALID, OCEAN, OUTOFPERIOD, MISSING, FILLED, isvalid, isinvalid, isvalid, isvalidorfilled

include("Mask.jl")

importall .Mask
using DataStructures
using Base.Dates

type ConfigEntry{LHS}
    lhs
    rhs
end



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

function Base.show(io::IO,c::Cube)
    println(io,"CABLAB data cube at ",c.base_dir)
    println(io,"Spatial resolution:  ",c.config.grid_width,"x",c.config.grid_height," at ",c.config.spatial_res," degrees.")
    println(io,"Temporal resolution: ",c.config.start_time," to ",c.config.end_time," at ",c.config.temporal_res,"daily time steps")
    print(  io,"Variables:           ")
    for v in c.dataset_files
        print(io,v," ")
    end
    println(io)
end


"A SubCube is a representation of a certain region or time range returned by the getCube function."
immutable SubCube{T} <: AbstractSubCube{T,3}
  cube::Cube #Parent cube
  variable::UTF8String #Variable
  sub_grid::Tuple{Int,Int,Int,Int} #grid_y1,grid_y2,grid_x1,grid_x2
  sub_times::NTuple{6,Int} #y1,i1,y2,i2,ntime,NpY
  lonAxis::LonAxis
  latAxis::LatAxis
  timeAxis::TimeAxis
end
axes(s::SubCube)=CubeAxis[s.lonAxis,s.latAxis,s.timeAxis]

"A SubCubePerm is a representation of a permutation of region or time range returned by the getCube function."
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
Base.size(s::SubCubePerm)=(s.perm[1]==1 ? length(s.parent.lonAxis) : s.perm[1]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
                           s.perm[2]==1 ? length(s.parent.lonAxis) : s.perm[2]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis),
                           s.perm[3]==1 ? length(s.parent.lonAxis) : s.perm[3]==2 ? length(s.parent.latAxis) : length(s.parent.timeAxis))



"A SubCube containing several variables"
immutable SubCubeV{T} <: AbstractSubCube{T,4}
    cube::Cube #Parent cube
    variable::Vector{UTF8String} #Variable
    sub_grid::Tuple{Int,Int,Int,Int} #grid_y1,grid_y2,grid_x1,grid_x2
    sub_times::NTuple{6,Int} #y1,i1,y2,i2,ntime,NpY
    lonAxis::LonAxis
    latAxis::LatAxis
    timeAxis::TimeAxis
    varAxis::VariableAxis
end

"A Permutation of a SubCube containing several variables"
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

Base.permutedims{T}(c::SubCube{T},perm::NTuple{3,Int})=SubCubePerm(c,perm)
Base.permutedims{T}(c::SubCubeV{T},perm::NTuple{4,Int})=SubCubeVPerm(c,perm)


"""

    getCubeData(cube::Cube;variable,time,latitude,longitude)

The following keyword arguments are accepted:

- *variable*: an variable index or name or an iterable returning multiple of these (var1, var2, ...)
- *time*: a single datetime.datetime object or a 2-element iterable (time_start, time_end)
- *latitude*: a single latitude value or a 2-element iterable (latitude_start, latitude_end)
- *longitude*: a single longitude value or a 2-element iterable (longitude_start, longitude_end)

Returns a dictionary mapping variable names --> arrays of dimension (longitude, latitude, time)

http://earthsystemdatacube.org
"""
function getCubeData(cube::Cube;variable=Int[],time=[],latitude=[],longitude=[])
    #First fill empty inputs
    isempty(variable) && (variable = defaultvariable(cube))
    isempty(time)     && (time     = defaulttime(cube))
    isempty(latitude) && (latitude = defaultlatitude(cube))
    isempty(longitude)&& (longitude= defaultlongitude(cube))
    getCubeData(cube,variable,time,latitude,longitude)
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

"Returns a vector of DateTime objects giving the time indices returned by a respective call to getCubeData."
function getTimeRanges(c::Cube,y1,y2,i1,i2)
    NpY    = ceil(Int,365/c.config.temporal_res)
    YearStepRange(y1,i1,y2,i2,c.config.temporal_res,NpY)
end

#Convert single input to vectors
function getCubeData{T<:Union{Integer,AbstractString}}(cube::Cube,
                variable::Union{AbstractString,Integer,AbstractVector{T}},
                time::Union{Tuple{TimeType,TimeType},TimeType},
                latitude::Union{Tuple{Real,Real},Real},
                longitude::Union{Tuple{Real,Real},Real})

  isa(time,TimeType) && (time=(time,time))
  isa(latitude,Real) && (latitude=(latitude,latitude))
  isa(longitude,Real) && (longitude=(longitude,longitude))
  isa(variable,AbstractVector) && isa(eltype(variable),Integer) && (variable=[cube.config.dataset_files[i] for i in variable])
  isa(variable,Integer) && (variable=dataset_files[i])
  getCubeData(cube,variable,time,longitude,latitude)
end

x2lon(x,config)   = (x+config.grid_x0-1)*config.spatial_res - 180.0
lon2x(lon,config) = round(Int,(180.0 + lon) / config.spatial_res) - config.grid_x0
y2lat(y,config)   = 90.0 - (y+config.grid_y0-1)*config.spatial_res
lat2y(lat,config) = round(Int,(90.0 - lat) / config.spatial_res) - config.grid_y0

function getLonLatsToRead(config,longitude,latitude)
  grid_y1 = lat2y(latitude[2],config) + 1
  grid_y2 = lat2y(latitude[1],config)
  grid_x1 = lon2x(longitude[1],config) + 1
  grid_x2 = lon2x(longitude[2],config)
  grid_x1==grid_x2+1 && (grid_x2+=1)
  grid_y1==grid_y2+1 && (grid_y2+=1)
  grid_y1,grid_y2,grid_x1,grid_x2
end



function getLandSeaMask!(mask::Array{UInt8,3},cube::Cube,grid_x1,nx,grid_y1,ny)
  filename=joinpath(cube.base_dir,"mask","mask.nc")
  if isfile(filename)
      ncread!(filename,"mask",sub(mask,:,:,1),start=[grid_x1,grid_y1],count=[nx,ny])
      nT=size(mask,3)
      for itime=2:nT,ilat=1:size(mask,2),ilon=1:size(mask,1)
          mask[ilon,ilat,itime]=mask[ilon,ilat,1]
      end
      scale!(mask,UInt8(5))
  end
  ncclose(filename)
end

function getLandSeaMask!(mask::Array{UInt8,4},cube::Cube,grid_x1,nx,grid_y1,ny)
  filename=joinpath(cube.base_dir,"mask","mask.nc")
  if isfile(filename)
      ncread!(filename,"mask",sub(mask,:,:,1,1),start=[grid_x1,grid_y1],count=[nx,ny])
      nT=size(mask,3)
      for ivar=1:size(mask,4),itime=2:nT,ilat=1:size(mask,2),ilon=1:size(mask,1)
          mask[ilon,ilat,itime,ivar]=mask[ilon,ilat,1,1]
      end
      scale!(mask,UInt8(5))
  end
  ncclose(filename
  )
end

function getCubeData(cube::Cube,
                variable::AbstractString,
                time::Tuple{TimeType,TimeType},
                latitude::Tuple{Real,Real},
                longitude::Tuple{Real,Real})
    # This function is doing the actual reading
    config=cube.config

    grid_y1,grid_y2,grid_x1,grid_x2 = getLonLatsToRead(config,longitude,latitude)
    y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)

    datafiles=sort!(readdir(joinpath(cube.base_dir,"data",variable)))
    #yfirst=parse(Int,datafiles[1][1:4])

    t=vartype(NetCDF.open(joinpath(cube.base_dir,"data",variable,datafiles[1]),variable))

    return SubCube{t}(cube,variable,
      (grid_y1,grid_y2,grid_x1,grid_x2),
      (y1,i1,y2,i2,ntime,NpY),
      LonAxis(x2lon(grid_x1,config):config.spatial_res:x2lon(grid_x2,config)),
      LatAxis(y2lat(grid_y1,config):-config.spatial_res:y2lat(grid_y2,config)),
      TimeAxis(getTimeRanges(cube,y1,y2,i1,i2)))
end

"Construct a subcube with many variables"
function getCubeData{T<:AbstractString}(cube::Cube,
                variable::Vector{T},
                time::Tuple{TimeType,TimeType},
                latitude::Tuple{Real,Real},
                longitude::Tuple{Real,Real})

config=cube.config

grid_y1,grid_y2,grid_x1,grid_x2 = getLonLatsToRead(config,longitude,latitude)
y1,i1,y2,i2,ntime,NpY = getTimesToRead(time[1],time[2],config)
  variableNew=UTF8String[]
  varTypes=DataType[]
  for i=1:length(variable)
    if haskey(cube.var_name_to_var_index,variable[i])
        datafiles=sort!(readdir(joinpath(cube.base_dir,"data",variable[i])))
        #yfirst=parse(Int,datafiles[1][1:4])
        t=vartype(NetCDF.open(joinpath(cube.base_dir,"data",variable[i],datafiles[1]),variable[i]))
        push!(variableNew,variable[i])
        push!(varTypes,t)
    else
      warn("Skipping variable $(variable[i]), not found in Datacube")
    end
  end
  tnew=reduce(promote_type,varTypes[1],varTypes)
  return SubCubeV{tnew}(cube,variable,
    (grid_y1,grid_y2,grid_x1,grid_x2),
    (y1,i1,y2,i2,ntime,NpY),
    LonAxis(x2lon(grid_x1,config):config.spatial_res:x2lon(grid_x2,config)),
    LatAxis(y2lat(grid_y1,config):-config.spatial_res:y2lat(grid_y2,config)),
    TimeAxis(getTimeRanges(cube,y1,y2,i1,i2)),
    VariableAxis(variableNew))
end

function readCubeData{T}(s::SubCube{T})
    grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
    y1,i1,y2,i2,ntime,NpY           = s.sub_times
    outar=Array(T,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)
    mask=zeros(UInt8,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)
    _read(s,(outar,mask),CartesianRange((grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime)))
    return CubeMem(CubeAxis[s.lonAxis,s.latAxis,s.timeAxis],outar,mask)
end

function readCubeData{T}(s::SubCubeV{T})
    grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
    y1,i1,y2,i2,ntime,NpY           = s.sub_times
    outar=Array(T,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))
    mask=zeros(UInt8,grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))
    _read(s,(outar,mask),CartesianRange((grid_x2-grid_x1+1,grid_y2-grid_y1+1,ntime,length(s.varAxis))))
    return CubeMem(CubeAxis[s.lonAxis,s.latAxis,s.timeAxis,s.varAxis],outar,mask)
end

"""
Add a function to read some CubeData in a permuted way, we will make a copy here for simplicity, however, this might change in the future
"""
function _read{T,N}(s::Union{SubCubeVPerm{T},SubCubePerm{T}},t::NTuple{2},r::CartesianRange{CartesianIndex{N}})  #;xoffs::Int=0,yoffs::Int=0,toffs::Int=0,voffs::Int=0,nx::Int=size(outar,findin(s.perm,1)[1]),ny::Int=size(outar,findin(s.perm,2)[1]),nt::Int=size(outar,findin(s.perm,3)[1]),nv::Int=size(outar,findin(s.perm,4)[1]))
  iperm=s.iperm
  perm=s.perm
  outar,mask=t
  sout=map(-,r.stop.I,(r.start-CartesianIndex{N}()).I)[iperm]
  #println("xoffs=$xoffs yoffs=$yoffs toffs=$toffs voffs=$voffs nx=$nx ny=$ny nt=$nt nv=$nv")
  outartemp=Array(T,sout...)
  masktemp=zeros(UInt8,sout...)
  _read(s.parent,(outartemp,masktemp),CartesianRange(CartesianIndex(r.start.I[iperm]),CartesianIndex(r.stop.I[iperm])))
  mypermutedims!(outar,outartemp,Val{perm})
  mypermutedims!(mask,masktemp,Val{perm})
end

getNv(r::CartesianRange{CartesianIndex{3}})=(0,1)
getNv(r::CartesianRange{CartesianIndex{4}})=(r.start.I[4]-1,r.stop.I[4]-r.start.I[4]+1)

function _read{T}(s::AbstractSubCube{T},t::NTuple{2},r::CartesianRange) #;xoffs::Int=0,yoffs::Int=0,toffs::Int=0,voffs::Int=0,nx::Int=size(outar,1),ny::Int=size(outar,2),nt::Int=size(outar,3),nv::Int=length(s.variable))

    outar,mask=t
    grid_y1,grid_y2,grid_x1,grid_x2 = s.sub_grid
    y1,i1,y2,i2,ntime,NpY           = s.sub_times

    grid_x1 = grid_x1 + r.start.I[1] - 1
    nx      = r.stop.I[1] - r.start.I[1] + 1
    grid_y1 = grid_y1 + r.start.I[2] - 1
    ny      = r.stop.I[2] - r.start.I[2] +1
    toffs   = r.start.I[3] - 1
    nt      = r.stop.I[3]  - r.start.I[3]+1
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

function readAllyears(s::SubCubeV,outar,mask,y1,i1,grid_x1,nx,grid_y1,ny,nt,voffs,nv,NpY)
    for iv in (voffs+1):(nv+voffs)
        outar2=sub(outar,:,:,:,iv-voffs)
        mask2=sub(mask,:,:,:,iv-voffs)
        ycur=y1   #Current year to read
        i1cur=i1  #Current time step in year
        itcur=1   #Current time step in output file
        fin = false
        while !fin
            fin,ycur,i1cur,itcur = readFromDataYear(s.cube,outar2,mask2,s.variable[iv],ycur,grid_x1,nx,grid_y1,ny,itcur,i1cur,nt,NpY)
        end
  end
end

function readFromDataYear{T}(cube::Cube,outar::AbstractArray{T,3},mask::AbstractArray{UInt8,3},variable,y,grid_x1,nx,grid_y1,ny,itcur,i1cur,ntime,NpY)
  filename=joinpath(cube.base_dir,"data",variable,string(y,"_",variable,".nc"))
  ntleft = ntime - itcur + 1
  nt = min(NpY-i1cur+1,ntleft)
  xr = grid_x1:(grid_x1+nx-1)
  yr = grid_y1:(grid_y1+ny-1)
  nanval=convert(T,NaN)
  #Make some assertions for inbounds
  @assert itcur>0
  @assert (itcur+nt-1)<=size(outar,3)
  @assert ny<=size(outar,2)
  @assert nx<=size(outar,1)
  @assert size(outar)==size(mask)
  if isfile(filename)
    v=NetCDF.open(filename,variable);
    scalefac::T = convert(T,get(v.atts,"scale_factor",one(T)))
    offset::T   = convert(T,get(v.atts,"add_offset",zero(T)))
    outar[1:nx,1:ny,itcur:(itcur+nt-1)]=v[xr,yr,i1cur:(i1cur+nt-1)]
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

function getMemHandle{T}(cube::AbstractCubeData{T},nblock,block_size)
  CachedArray(cube,nblock,block_size,CachedArrays.MaskedCacheBlock{T,length(block_size)})
end
getMemHandle(cube::AbstractCubeMem,nblock,block_size)=cube


end
