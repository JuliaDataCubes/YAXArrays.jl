module Proc
export removeMSC!, gapFillMSC, recurrences!, normalize, spatialMean, timeMean
importall ..DAT, ..CubeAPI

include("MSC.jl")
include("Outlier.jl")
include("Stats.jl")
importall .MSC, .Outlier, .Stats



end
