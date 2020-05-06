"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module ESDL
using Reexport
global const ESDLDefaults = (
  workdir = Ref("./"),
  recal   = Ref(false),
  chunksize  = Ref{Any}(:input),
  max_cache  = Ref(1e8),
  cubedir    = Ref(""),
  subsetextensions = [],
)
global const workdir=ESDLDefaults.workdir
global const recal=ESDLDefaults.recal
function __init__()
  ESDLDefaults.workdir[]   = get(ENV,"ESDL_WORKDIR","./")
  ESDLDefaults.max_cache[] = parse(Float64,get(ENV,"ESDL_MAX_CACHE","100")) * 1e6
  ESDLDefaults.cubedir[]   = get(ENV,"ESDL_CUBEDIR","")
end
ESDLdir(x::String)=ESDLDefaults.workdir[]=x
recalculate(x::Bool)=ESDLDefaults.recal[]=x
recalculate()=ESDLDefaults.recal[]
ESDLdir()=ESDLDefaults.workdir[]
export ESDLdir

include("ESDLTools.jl")
include("Cubes/Cubes.jl")
include("DatasetAPI/Datasets.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")

@reexport using Dates: Date, DateTime
@reexport using IntervalSets: (..)
@reexport using .Cubes: cubeinfo, concatenateCubes, caxes,
  subsetcube, readcubedata,renameaxis!, ESDLArray
@reexport using .Cubes.Axes: CubeAxis, RangeAxis, CategoricalAxis,
  getAxis

@reexport using .DAT: mapCube, getAxis, InDims, OutDims, Dataset,
      CubeTable, cubefittable, fittable #From DAT module
@reexport using .Proc: removeMSC, gapFillMSC,normalizeTS,
  getMSC, filterTSFFT, getNpY,savecube,loadcube,rmcube,
  getMedSC, extractLonLats, cubefromshape,
  gapfillpoly, spatialinterp #From Proc module
@reexport using .Datasets: Dataset, Cube, open_dataset
@reexport using .ESDLTools: @loadOrGenerate # from ESDL Tools

@deprecate saveCube(data, filename) savecube(data,filename)
@deprecate loadCube(filename) loadcube(filename)
@deprecate rmCube(filename) rmcube(filename)
@deprecate exportcube(data, filename; kwargs...) savecube(data, filename; backend=:netcdf, kwargs...)
@deprecate cubeproperties(x) getattributes(x)

#include("precompile.jl")
#_precompile_()

end # module
