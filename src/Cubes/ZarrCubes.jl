module ESDLZarr
import ....ESDL
import Distributed: myid
import Zarr: ZGroup, zopen, ZArray, NoCompressor, zgroup, zcreate, readblock!, S3Store, DirectoryStore
import ...Cubes: cubechunks, iscompressed, AbstractCubeData, getCubeDes,
  caxes,chunkoffset, subsetcube, axVal2Index, findAxis, S3Cube,
  getattributes, concatenateCubes, _subsetcube, workdir, readcubedata, saveCube,
  getsavefolder, check_overwrite,ESDLArray, CleanMe
import ESDL.Cubes.Axes: axname, CubeAxis, CategoricalAxis, RangeAxis, TimeAxis,
  axVal2Index_lb, axVal2Index_ub, get_step, getAxis
import Dates: Day,Hour,Minute,Second,Month,Year, Date, DateTime, TimeType
import IntervalSets: Interval, (..)
import CFTime: timedecode, timeencode, DateTimeNoLeap, DateTime360Day, DateTimeAllLeap
export (..), Cubes, getCubeData, CubeMask, cubeinfo
const spand = Dict("days"=>Day,"months"=>Month,"years"=>Year,"hours"=>Hour,"seconds"=>Second,"minutes"=>Minute)

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





end # module
