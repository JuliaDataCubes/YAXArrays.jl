module Proc
export removeMSC, gapFillMSC, recurrences, normalize, spatialMean, timeMean, @no_ocean
importall ..DAT, ..CubeAPI, ..Cubes
macro no_ocean(maskin,maskout)
    esc(quote
        if ($(maskin)[1] & OCEAN) > 0
            $maskout[:]=OCEAN
            return nothing
        end
    end)
end

include("MSC.jl")
include("Outlier.jl")
include("Stats.jl")
importall .MSC, .Outlier, .Stats



end
