"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module YAXArrays
global const YAXDefaults = (
  workdir = Ref("./"),
  recal   = Ref(false),
  chunksize  = Ref{Any}(:input),
  max_cache  = Ref(1e8),
  cubedir    = Ref(""),
  subsetextensions = [],
)
global const workdir=YAXDefaults.workdir
global const recal=YAXDefaults.recal
function __init__()
  YAXDefaults.workdir[]   = get(ENV,"YAXARRAY_WORKDIR","./")
  YAXDefaults.max_cache[] = parse(Float64,get(ENV,"YAXARRAY_MAX_CACHE","100")) * 1e6
  YAXDefaults.cubedir[]   = get(ENV,"YAXARRAY_CUBEDIR","")
end
YAXdir(x::String)=YAXDefaults.workdir[]=x
recalculate(x::Bool)=YAXDefaults.recal[]=x
recalculate()=YAXDefaults.recal[]
YAXdir()=YAXDefaults.workdir[]
export YAXdir

include("YAXTools.jl")
include("Cubes/Cubes.jl")
include("DatasetAPI/Datasets.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")

using .YAXTools: @reexport

@reexport using Dates: Date, DateTime
@reexport using IntervalSets: (..)
@reexport using .Cubes: cubeinfo, concatenateCubes, caxes,
  subsetcube, readcubedata,renameaxis!, YAXArray
@reexport using .Cubes.Axes: CubeAxis, RangeAxis, CategoricalAxis,
  getAxis

@reexport using .DAT: mapCube, getAxis, InDims, OutDims, Dataset,
      CubeTable, cubefittable, fittable #From DAT module
@reexport using .Proc: removeMSC, gapFillMSC,normalizeTS,
  getMSC, filterTSFFT, getNpY,savecube,loadcube,rmcube,
  getMedSC, extractLonLats, cubefromshape,
  gapfillpoly, spatialinterp #From Proc module
@reexport using .Datasets: Dataset, Cube, open_dataset
@reexport using .YAXTools: @loadOrGenerate # from YAXTools

@deprecate saveCube(data, filename) savecube(data,filename)
@deprecate loadCube(filename) loadcube(filename)
@deprecate rmCube(filename) rmcube(filename)
@deprecate exportcube(data, filename; kwargs...) savecube(data, filename; backend=:netcdf, kwargs...)
@deprecate cubeproperties(x) getattributes(x)

#include("precompile.jl")
#_precompile_()

end # module
