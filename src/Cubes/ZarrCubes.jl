module ESDLZarr
import ....ESDL
import Distributed: myid
import Zarr: ZGroup, zopen, ZArray, NoCompressor, zgroup, zcreate, readblock!, S3Store, DirectoryStore
import ...Cubes: cubechunks, iscompressed, AbstractCubeData, getCubeDes,
  caxes,chunkoffset, subsetcube, axVal2Index, findAxis, S3Cube,
  cubeproperties, concatenateCubes, _subsetcube, workdir, readcubedata, saveCube,
  getsavefolder, check_overwrite,ESDLArray, CleanMe
import ESDL.Cubes.Axes: axname, CubeAxis, CategoricalAxis, RangeAxis, TimeAxis,
  axVal2Index_lb, axVal2Index_ub, get_step, getAxis
import Dates: Day,Hour,Minute,Second,Month,Year, Date, DateTime, TimeType
import IntervalSets: Interval, (..)
import CFTime: timedecode, timeencode, DateTimeNoLeap, DateTime360Day, DateTimeAllLeap
export (..), Cubes, getCubeData, CubeMask, cubeinfo
const spand = Dict("days"=>Day,"months"=>Month,"years"=>Year,"hours"=>Hour,"seconds"=>Second,"minutes"=>Minute)

const ZArrayCube{T,M} = ESDLArray{T,M,<:ZArray} where {T,M}

iscompressed(z::ZArray)=!isa(z.metadata.compressor,NoCompressor)

prependrange(r::AbstractRange,n) = n==0 ? r : range(first(r)-n*step(r),last(r),length=n+length(r))
function prependrange(r::AbstractVector,n)
  if n==0
    return r
  else
    step = r[2]-r[1]
    first = r[1] - step*n
    last = r[1] - step
    radd = range(first,last,length=n)
    return [radd;r]
  end
end

defaultcal(::Type{<:TimeType}) = "standard"
defaultcal(::Type{<:DateTimeNoLeap}) = "noleap"
defaultcal(::Type{<:DateTimeAllLeap}) = "allleap"
defaultcal(::Type{<:DateTime360Day}) = "360_day"

datetodatetime(vals::AbstractArray{<:Date}) = DateTime.(vals)
datetodatetime(vals) = vals

function dataattfromaxis(ax::CubeAxis{<:Number},n)
    prependrange(ax.values,n), Dict{String,Any}()
end
function dataattfromaxis(ax::CubeAxis,n)
    prependrange(1:length(ax.values),n), Dict{String,Any}("_ARRAYVALUES"=>collect(ax.values))
end
function dataattfromaxis(ax::CubeAxis{T},n) where T<:TimeType
    data = timeencode(datetodatetime(ax.values),"days since 1980-01-01",defaultcal(T))
    prependrange(data,n), Dict{String,Any}("units"=>"days since 1980-01-01","calendar"=>defaultcal(T))
end



defaultfillval(T::Type{<:AbstractFloat}) = convert(T,1e32)
defaultfillval(::Type{Float16}) = Float16(3.2e4)
defaultfillval(T::Type{<:Integer}) = typemax(T)

function ZArrayCube(axlist; folder = tempname(), kwargs...)
  createDataset(ZarrDataset, axlist; path = folder, kwargs...)
end


import DataStructures: counter

Cube(s::String;kwargs...) = Cube(zopen(s,"r");kwargs...)
function Cube(;kwargs...)
  if !isempty(ESDL.ESDLDefaults.cubedir[])
    Cube(ESDL.ESDLDefaults.cubedir[];kwargs...)
  else
    S3Cube(;kwargs...)
  end
end
function CubeMask(s::String,v::String;kwargs...)
  vname =  string(v,"_mask")
  c = Cube(zopen(s);varlist=[vname],static=true,kwargs...)
  c.properties["labels"] = known_labels[vname]
  c.properties["name"]   = known_names[vname]
  readcubedata(c)
end
CubeMask(v;kwargs...) = CubeMask(ESDL.ESDLDefaults.cubedir[],v;static=true,kwargs...)


@deprecate getCubeData(c;longitude=(-180.0,180.0),latitude=(-90.0,90.0),kwargs...) subsetcube(c;lon=longitude,lat=latitude,kwargs...)

sorted(x,y) = x<y ? (x,y) : (y,x)

#TODO move everything that is subset-related to its own file or to axes.jl
interpretsubset(subexpr::Union{CartesianIndices{1},LinearIndices{1}},ax) = subexpr.indices[1]
interpretsubset(subexpr::CartesianIndex{1},ax)   = subexpr.I[1]
interpretsubset(subexpr,ax)                      = axVal2Index(ax,subexpr,fuzzy=true)
function interpretsubset(subexpr::NTuple{2,Any},ax)
  x, y = sorted(subexpr...)
  Colon()(sorted(axVal2Index_lb(ax,x),axVal2Index_ub(ax,y))...)
end
interpretsubset(subexpr::NTuple{2,Int},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(map(T,subexpr),ax)
interpretsubset(subexpr::UnitRange{Int64},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(T(first(subexpr))..T(last(subexpr)+1),ax)
interpretsubset(subexpr::Interval,ax)       = interpretsubset((subexpr.left,subexpr.right),ax)
interpretsubset(subexpr::AbstractVector,ax::CategoricalAxis)      = axVal2Index.(Ref(ax),subexpr,fuzzy=true)

#TODO move this to Axes.jl
axcopy(ax::RangeAxis,vals) = RangeAxis(axname(ax),vals)
axcopy(ax::CategoricalAxis,vals) = CategoricalAxis(axname(ax),vals)

function _subsetcube(z::AbstractCubeData, subs;kwargs...)
  if :region in keys(kwargs)
    kwargs = collect(Any,kwargs)
    ireg = findfirst(i->i[1]==:region,kwargs)
    reg = splice!(kwargs,ireg)
    haskey(known_regions,reg[2]) || error("Region $(reg[2]) not known.")
    lon1,lat1,lon2,lat2 = known_regions[reg[2]]
    push!(kwargs,:lon=>lon1..lon2)
    push!(kwargs,:lat=>lat1..lat2)
  end
  newaxes = deepcopy(caxes(z))
  foreach(kwargs) do kw
    axdes,subexpr = kw
    axdes = string(axdes)
    iax = findAxis(axdes,caxes(z))
    if isa(iax,Nothing)
      throw(ArgumentError("Axis $axdes not found in cube"))
    else
      oldax = newaxes[iax]
      subinds = interpretsubset(subexpr,oldax)
      subs2 = subs[iax][subinds]
      subs[iax] = subs2
      if !isa(subinds,AbstractVector) && !isa(subinds,AbstractRange)
        newaxes[iax] = axcopy(oldax,oldax.values[subinds:subinds])
      else
        newaxes[iax] = axcopy(oldax,oldax.values[subinds])
      end
    end
  end
  substuple = ntuple(i->subs[i],length(subs))
  inewaxes = findall(i->isa(i,AbstractVector),substuple)
  newaxes = newaxes[inewaxes]
  @assert length.(newaxes) == map(length,filter(i->isa(i,AbstractVector),collect(substuple)))
  newaxes, substuple
end

include(joinpath(@__DIR__,"../CubeAPI/countrydict.jl"))

Base.getindex(a::AbstractCubeData;kwargs...) = subsetcube(a;kwargs...)

function saveCube(z::ZArrayCube, name::AbstractString; overwrite=false, chunksize=nothing, compressor=NoCompressor())
  if z.subset === nothing && !z.persist && isa(z.a.storage, DirectoryStore) && chunksize==nothing && isa(compressor, NoCompressor)
    newfolder = joinpath(workdir[], name)
    check_overwrite(newfolder, overwrite)
    # the julia cp implentation currently can only deal with files <2GB
    # the issue is:
    # https://github.com/JuliaLang/julia/issues/14574
    # mv(c.folder,newfolder)
    folder = splitdir(z.a.storage.folder)
    run(`mv $(folder[1]) $(newfolder)`)
    #TODO persist does not exist anymore, save metadata
    z.persist = true
    z.a = zopen(newfolder * "/layer")
  else
    invoke(saveCube,Tuple{AbstractCubeData, AbstractString},z,name;overwrite=overwrite, chunksize=chunksize===nothing ? cubechunks(z) : chunksize, compressor=compressor)
  end
end

"""
    loadCube(name::String)
Loads a cube that was previously saved with [`saveCube`](@ref). Returns a
`TempCube` object.
"""
function loadCube(name::String)
  newfolder=joinpath(workdir[],name)
  isdir(newfolder) || error("$(name) does not exist")
  Cube(newfolder)
end

"""
    rmCube(name::String)

Deletes a memory-mapped data cube.
"""
function rmCube(name::String)
  newfolder=joinpath(workdir[],name)
  isdir(newfolder) && rm(newfolder,recursive=true)
  nothing
end
export rmCube, loadCube


using Markdown
struct ESDLVarInfo
  project::String
  longname::String
  units::String
  url::String
  comment::String
  reference::String
end
Base.isless(a::ESDLVarInfo, b::ESDLVarInfo) = isless(string(a.project, a.longname),string(b.project, b.longname))

import Base.show
function show(io::IO,::MIME"text/markdown",v::ESDLVarInfo)
    un=v.units
    url=v.url
    re=v.reference
    pr = v.project
    ln = v.longname
    co = v.comment
    mdt=md"""
### $ln
*$(co)*

* **Project** $(pr)
* **units** $(un)
* **Link** $(url)
* **Reference** $(re)
"""
    mdt[3].items[1][1].content[3]=[" $pr"]
    mdt[3].items[2][1].content[3]=[" $un"]
    mdt[3].items[3][1].content[3]=[" $url"]
    mdt[3].items[4][1].content[3]=[" $re"]
    show(io,MIME"text/markdown"(),mdt)
end
show(io::IO,::MIME"text/markdown",v::Vector{ESDLVarInfo})=foreach(x->show(io,MIME"text/markdown"(),x),v)
import Zarr: zname

"""
    cubeinfo(cube)

Shows the metadata and citation information on variables contained in a cube.
"""
function cubeinfo(cube::ZArrayCube)
    p = cube.properties
    variable = zname(cube.a)
    vi=ESDLVarInfo(
      get(p,"project_name", "unknown"),
      get(p,"long_name",variable),
      get(p,"units","unknown"),
      get(p,"url","no link"),
      get(p,"comment",variable),
      get(p,"references","no reference")
    )
end


end # module
