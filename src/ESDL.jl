"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module ESDL
import Dates: Date
export Date
export ESDLdir, getAxis
export Cube, getCubeData,readcubedata,CubeMem,CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, SpatialPointAxis, saveCube, loadCube,
        RangeAxis, CategoricalAxis, MSCAxis, ScaleAxis, QuantileAxis, MethodAxis, cubeinfo, @caxis_str,splitdim,
        axVal2Index, mapCubeSimple, concatenateCubes, NetCDFCube, mergeAxes, caxes, subsetcube, CubeMask, renameaxis! #From Cube module
export registerDATFunction, mapCube, reduceCube, getAxis, InDims, OutDims, (..), Dataset, ESDLDataset,S3Cube,
        CubeTable, AsArray,AsAxisArray,AsDataFrame, cubefittable, TableAggregator, fittable #From DAT module
export cubeAnomalies, removeMSC, gapFillMSC, normalizeTS,DATfitOnline,
  sampleLandPoints, toPointAxis, getMSC, filterTSFFT, getNpY,
  getMedSC, extractLonLats,simpleAnomalies,spatialinterp,cubefromshape, exportcube, gapfillpoly #From Proc module
export rmCube # From CachedArrays
export @loadOrGenerate # from ESDL Tools
import Zarr
global const ESDLDefaults = (
  workdir = Ref("./"),
  recal   = Ref(false),
  compressor = Ref{Zarr.Compressor}(Zarr.NoCompressor()),
  chunksize  = Ref{Any}(:input),
  max_cache  = Ref(1e8),
  cubedir    = Ref(""),
)
global const workdir=ESDLDefaults.workdir
global const recal=ESDLDefaults.recal
function __init__()
  ESDLDefaults.workdir[]   = get(ENV,"ESDL_WORKDIR","./")
  ESDLDefaults.max_cache[] = parse(Float64,get(ENV,"ESDL_MAX_CACHE","100")) * 1e6
  ESDLDefaults.cubedir[]   = if isdir("/home/jovyan/work/datacube/ESDCv2.0.0/esdc-8d-0.25deg-184x90x90-2.0.0.zarr/")
    "/home/jovyan/work/datacube/ESDCv2.0.0/esdc-8d-0.25deg-184x90x90-2.0.0.zarr/"
  else
    get(ENV,"ESDL_CUBEDIR","")
  end
end
ESDLdir(x::String)=ESDLDefaults.workdir[]=x
recalculate(x::Bool)=ESDLDefaults.recal[]=x
recalculate()=ESDLDefaults.recal[]
ESDLdir()=ESDLDefaults.workdir[]
export ESDLdir

include("ESDLTools.jl")
include("Cubes/Cubes.jl")
#include("CubeAPI/CubeAPI.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")

using .Cubes, .DAT, .Proc, .ESDLTools

#include("precompile.jl")
#_precompile_()

end # module
