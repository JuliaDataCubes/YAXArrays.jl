module YAXArrays
global const YAXDefaults = (
    workdir = Ref("./"),
    recal = Ref(false),
    chunksize = Ref{Any}(:input),
    max_cache = Ref(1e8),
    cubedir = Ref(""),
    subsetextensions = [],
)
global const workdir = YAXDefaults.workdir
global const recal = YAXDefaults.recal
function __init__()
    YAXDefaults.workdir[] = get(ENV, "YAXARRAY_WORKDIR", "./")
    YAXDefaults.max_cache[] = parse(Float64, get(ENV, "YAXARRAY_MAX_CACHE", "500")) * 1e6
    YAXDefaults.cubedir[] = get(ENV, "YAXARRAY_CUBEDIR", "")
end
YAXdir(x::String) = YAXDefaults.workdir[] = x
recalculate(x::Bool) = YAXDefaults.recal[] = x
recalculate() = YAXDefaults.recal[]
YAXdir() = YAXDefaults.workdir[]
export YAXdir

include("YAXTools.jl")
include("Cubes/Cubes.jl")
include("DatasetAPI/Datasets.jl")
include("DAT/DAT.jl")

using Reexport: @reexport
using YAXArrayBase: getattributes

@reexport using Dates: Date, DateTime
@reexport using IntervalSets: (..)
@reexport using .Cubes
@reexport using .Cubes.Axes

@reexport using .DAT
@reexport using .Datasets
@reexport using .YAXTools: @loadOrGenerate # from YAXTools

# include("precompile.jl")
# _precompile_()

end # module
