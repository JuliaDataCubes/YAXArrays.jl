module Proc
export cubeAnomalies, removeMSC, gapFillMSC, normalizeTS, simpleAnomalies,
  sampleLandPoints, getMSC, filterTSFFT, getNpY, getMedSC, DATfitOnline,
  spatialinterp, extractLonLats, cubePCA, rotation_matrix, transformPCA, explained_variance,exportcube
using ..DAT, ..Cubes

import Dates.year
"""
    getNpY(cube::AbstractCubeData)
    getNpY(cube::InputCube)

Get the number of time steps per year
"""
function getNpY(cube::AbstractCubeData)
    axlist = caxes(cube)
    isTime = [isa(a,TimeAxis) for a in axlist]
    timax = axlist[isTime][1]
    years = year.(timax.values)
    years[end] > years[1] + 1 || error("Must have at least 3 years to calculate MSC")
    return count(i -> i == years[1] + 1, years)
end
getNpY(cube::InputCube)=getNpY(cube.cube)

include("MSC.jl")
include("Stats.jl")
include("CubeIO.jl")
include("TSDecomposition.jl")
include("remap.jl")
include("Shapes.jl")
using .ReSample, .MSC, .Stats, .CubeIO,
  .TSDecomposition



end
