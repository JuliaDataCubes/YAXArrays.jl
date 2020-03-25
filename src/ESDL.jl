"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module ESDL
using Reexport
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

include("ESDLTools.jl")
include("Cubes/Cubes.jl")
include("DatasetAPI/Datasets.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")

@reexport using Dates: Date, DateTime
export ESDLdir
@reexport using .Cubes: Cube, CubeMem, CubeAxis, saveCube,
        RangeAxis, CategoricalAxis, cubeinfo, splitdim, getAxis,
        concatenateCubes, caxes, subsetcube, renameaxis! #From Cube module
@reexport using .DAT: mapCube, getAxis, InDims, OutDims, (..), Dataset, S3Cube,
      CubeTable, cubefittable, fittable #From DAT module
@reexport using .Proc: removeMSC, gapFillMSC,normalizeTS,
  getMSC, filterTSFFT, getNpY,
  getMedSC, extractLonLats, cubefromshape,
  exportcube, gapfillpoly #From Proc module
@reexport using ESDLTools: @loadOrGenerate # from ESDL Tools


#include("precompile.jl")
#_precompile_()

end # module
