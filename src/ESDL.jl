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
        RangeAxis, CategoricalAxis, MSCAxis, ScaleAxis, QuantileAxis, MethodAxis, cubeinfo, @caxis_str,
        axVal2Index, mapCubeSimple, concatenateCubes, NetCDFCube, mergeAxes, caxes, subsetcube, CubeMask, renameaxis! #From Cube module
export registerDATFunction, mapCube, reduceCube, getAxis, InDims, OutDims, (..), Dataset, ESDLDataset,S3Cube,
        CubeTable, AsArray,AsAxisArray,AsDataFrame, cubefittable, TableAggregator, fittable #From DAT module
export cubeAnomalies, removeMSC, gapFillMSC, normalizeTS,DATfitOnline,
  sampleLandPoints, toPointAxis, getMSC, filterTSFFT, getNpY,
  getMedSC, extractLonLats,simpleAnomalies,spatialinterp,cubefromshape
  exportcube #From Proc module
export rmCube # From CachedArrays
export @loadOrGenerate # from ESDL Tools

global const workdir=String["./"]
global const recal=Bool[false]
haskey(ENV,"ESDL_WORKDIR") && (workdir[1]=ENV["ESDL_WORKDIR"])
ESDLdir(x::String)=workdir[1]=x
recalculate(x::Bool)=recal[1]=x
recalculate()=recal[1]
ESDLdir()=workdir[1]
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
