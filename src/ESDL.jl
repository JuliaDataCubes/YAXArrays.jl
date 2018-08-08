"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module ESDL
export ESDLdir, getAxis
export Cube, getCubeData,readCubeData,CubeMem,CubeAxis, TimeAxis, TimeHAxis, VariableAxis, LonAxis, FitAxis, LatAxis, CountryAxis, SpatialPointAxis, saveCube, loadCube,
        RangeAxis, CategoricalAxis, MSCAxis, getSingVal, TimeScaleAxis, QuantileAxis, MethodAxis, RemoteCube, showVarInfo, @caxis_str,
        axVal2Index, mapCubeSimple, concatenateCubes, SliceCube, NetCDFCube, mergeAxes #From Cube module
export registerDATFunction, mapCube, reduceCube, getAxis, InDims, OutDims,AsArray,AsAxisArray,AsDataFrame #From DAT module
export cubeAnomalies, removeMSC, gapFillMSC, normalizeTS,DATfitOnline,
  sampleLandPoints, toPointAxis, getMSC, filterTSFFT, getNpY,
  getMedSC, extractLonLats,simpleAnomalies,
  cubePCA, rotation_matrix, transformPCA, explained_variance, exportcube #From Proc module
export TempCube, openTempCube, rmCube # From CachedArrays
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
include("CubeAPI/CubeAPI.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")

importall .Cubes, .CubeAPI, .DAT, .Proc, .ESDLTools

end # module
