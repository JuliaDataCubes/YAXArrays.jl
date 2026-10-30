module YAXArrays

"""
Default configuration for YAXArrays, has the following fields:

- `workdir[]::String = "./"` The default location for temporary cubes.
- `recal[]::Bool = false` set to true if you want `@loadOrGenerate` to always recalculate the results.
- `chunksize[]::Any = :input` Set the default output chunksize.
- `max_cache[]::Float64 = 1e8` The maximum cache used by mapCube.
- `cubedir[]::""` the default location for `Cube()` without an argument.
- `subsetextensions::Array{Any} = []` List of registered functions, that convert subsetting input into dimension boundaries. 
"""
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
include("helpers.jl")
include("dims.jl")
include("YAXTools.jl")
include("Cubes/Cubes.jl")
include("DatasetAPI/Datasets.jl")
include("DAT/DAT.jl")
include("DAT/xmap.jl")
include("DAT/counter.jl")

using Reexport: @reexport
using YAXArrayBase: getattributes

@reexport using Dates: Date, DateTime
@reexport using IntervalSets: (..)
@reexport using DimensionalData: DimensionalData, Dim, At, Touches, Near, Where, Contains, lookup
@reexport using .Cubes

#@reexport using .Cubes.Axes

@reexport using .DAT
@reexport using .Xmap
@reexport using .Datasets
using PrecompileTools
# from YAXTools

# include("precompile.jl")
# _precompile_()

@setup_workload begin
    @compile_workload begin
        xax = DD.X(1:10)
        yax = DD.Y(1:10)
        data = rand(10,10)
        arr = YAXArray((xax, yax), data, Dict())
        path = tempname()*".zarr"
        savecube(arr, path)
        arrdisk = Cube(path)
        YAXArray(DD.dims(arr), arrdisk.data, arr.properties)
    end
end

end # module
