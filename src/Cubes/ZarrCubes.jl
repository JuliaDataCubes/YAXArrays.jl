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


function ZArrayCube(axlist; folder = tempname(), kwargs...)
  createDataset(ZarrDataset, axlist; path = folder, kwargs...)
end


import DataStructures: counter
function CubeMask(s::String,v::String;kwargs...)
  vname =  string(v,"_mask")
  c = Cube(zopen(s);varlist=[vname],static=true,kwargs...)
  c.properties["labels"] = known_labels[vname]
  c.properties["name"]   = known_names[vname]
  readcubedata(c)
end
CubeMask(v;kwargs...) = CubeMask(ESDL.ESDLDefaults.cubedir[],v;static=true,kwargs...)


@deprecate getCubeData(c;longitude=(-180.0,180.0),latitude=(-90.0,90.0),kwargs...) subsetcube(c;lon=longitude,lat=latitude,kwargs...)


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
