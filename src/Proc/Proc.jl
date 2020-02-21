module Proc
export cubeAnomalies, removeMSC, gapFillMSC, normalizeTS, simpleAnomalies,
  sampleLandPoints, getMSC, filterTSFFT, getNpY, getMedSC, DATfitOnline,
  spatialinterp, extractLonLats, cubePCA, rotation_matrix, transformPCA, explained_variance,exportcube,
  gapfillpoly
import ..Cubes: ESDLArray, AbstractCubeData, getAxis
import ..DAT: mapCube

import Dates.year
"""
    getNpY(cube::AbstractCubeData)
    getNpY(cube::InputCube)

Get the number of time steps per year
"""
function getNpY(cube::AbstractCubeData)
    timax = getAxis("Time",cube)
    years = year.(timax.values)
    years[end] > years[1] + 1 || error("Must have at least 3 years to estimate number of time steps per year")
    return count(i -> i == years[1] + 1, years)
end

include("MSC.jl")
include("Stats.jl")
include("CubeIO.jl")
include("TSDecomposition.jl")
include("remap.jl")
include("Shapes.jl")
using .ReSample, .MSC, .Stats, .CubeIO,
  .TSDecomposition



end
