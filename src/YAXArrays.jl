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

using .YAXTools: @reexport
using YAXArrayBase: getattributes

@reexport using Dates: Date, DateTime
@reexport using IntervalSets: (..)
@reexport using .Cubes: concatenatecubes, caxes,
  subsetcube, readcubedata,renameaxis!, YAXArray
@reexport using .Cubes.Axes: CubeAxis, RangeAxis, CategoricalAxis,
  getAxis

@reexport using .DAT: mapCube, getAxis, InDims, OutDims, Dataset,
      CubeTable, cubefittable, fittable, savecube, loadcube, rmcube, 
      MovingWindow #From DAT module
@reexport using .Datasets: Dataset, Cube, open_dataset
@reexport using .YAXTools: @loadOrGenerate # from YAXTools

@deprecate saveCube(data, filename) savecube(data,filename)
@deprecate loadCube(filename) loadcube(filename)
@deprecate rmCube(filename) rmcube(filename)
@deprecate exportcube(data, filename; kwargs...) savecube(data, filename; backend=:netcdf, kwargs...)
@deprecate cubeproperties(x) getattributes(x)
@deprecate concantenateCubes(args...) concatenatecubes(args...)

#include("precompile.jl")
#_precompile_()

end # module
