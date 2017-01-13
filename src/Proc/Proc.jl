module Proc
export DAT_detectAnomalies!, removeMSC, gapFillMSC, normalizeTS,
  sampleLandPoints, toPointAxis, getMSC, filterTSFFT, getNpY,timespacequantiles,timelonlatquantiles, getMedSC,DATfitOnline,
  extractLonLats
importall ..DAT, ..CubeAPI, ..Cubes
macro no_ocean(maskin,maskout)
    esc(quote
        if ($(maskin)[1] & OCEAN) == OCEAN
            $maskout[:]=OCEAN
            return nothing
        end
    end)
end

function getNpY(cube::AbstractCubeData)
    axlist=axes(cube)
    isTime=[isa(a,TimeAxis) for a in axlist]
    return axlist[isTime][1].values.NPY
end

include("OnlineStats.jl")
include("MSC.jl")
include("Outlier.jl")
include("Stats.jl")
include("CubeIO.jl")
include("TSDecomposition.jl")
importall .MSC, .Outlier, .Stats, .CubeIO, .TSDecomposition, .DATOnlineStats



end
