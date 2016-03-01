"""
## The Earth System Data Cube
![](http://earthsystemdatacube.net/wp-content/uploads/2015/07/EarthDataCube3.png "The DataCube")

Some info on the project...
"""
module CABLAB
export Cube, getCubeData,getTimeRanges,CubeMem,CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis #From Cube module
export @registerDATFunction, joinVars #From DAT module
export axVal2Index, plotTS, plotMAP #From Plot module
export removeMSC!, gapFillMSC, recurrences!, normalize, timeMean, spatialMean #From Proc module

include("CubeAPI/CubeAPI.jl")
include("CachedArrays/CachedArrays.jl")
include("DAT/DAT.jl")
include("Proc/Proc.jl")
include("Plot/Plot.jl")


importall .CubeAPI, .DAT, .Proc, .Plot

end # module
