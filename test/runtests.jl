using YAXArrays
using Test
using TestItemRunner
using Dates
using YAXArrayBase
using YAXArrays: YAXArrays as YAX

@run_package_tests

include("tools.jl")
#include("Cubes/axes.jl")
include("Cubes/cubes.jl")
include("Cubes/transformedcubes.jl")
include("Cubes/batchextraction.jl")

include("Datasets/datasets.jl")

include("DAT/PickAxisArray.jl")
include("DAT/MovingWindow.jl")
include("DAT/tablestats.jl")
include("DAT/mapcube.jl")
include("DAT/xmap.jl")
include("DAT/DAT.jl")
include("DAT/loopchunks.jl")
