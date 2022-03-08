using Base.Iterators: Iterators, product
using ..Datasets: getsavefolder, Cube

"""
    savecube(cube,name::String)

Save a [`YAXArray`](@ref) to the folder `name` in the YAXArray working directory.
"""
function savecube(
    c,
    name::AbstractString;
    chunksize = Dict(),
    max_cache = 1e8,
    backend = :zarr,
    backendargs...,
)
    allax = caxes(c)
    if !isa(chunksize, AbstractDict) && !isa(chunksize, NamedTuple)
        @warn "Chunksize must be provided as a Dict mapping axis names to chunk size in the future"
        chunksize = OrderedDict(axname(i[1]) => i[2] for i in zip(allax, chunksize))
    end
    firstaxes = sort!([findAxis(String(k), allax) for k in keys(chunksize)])
    lastaxes = setdiff(1:length(allax), firstaxes)
    allax = allax[[firstaxes; lastaxes]]
    dl = cumprod(length.(caxes(c)))
    isplit = findfirst(i -> i > max_cache / sizeof(eltype(c)), dl)
    isplit isa Nothing && (isplit = length(dl) + 1)
    forcesingle = (isplit + 1) < length(firstaxes)
    axin = allax[1:isplit-1]
    axn = axname.(axin)
    indims = InDims(axn...)
    outdims = OutDims(
        axn...,
        backend = backend,
        chunksize = chunksize,
        path = name;
        backendargs...,
    )
    function cop(xout, xin)
        xout .= xin
    end
    if forcesingle
        nprocs() > 1 && println("Forcing single core processing because of bad chunk size")
        o = mapCube(
            cop,
            c,
            indims = indims,
            outdims = outdims,
            ispar = false,
            max_cache = max_cache,
        )
    else
        o = mapCube(cop, c, indims = indims, outdims = outdims, max_cache = max_cache)
    end
end

function loadcube(s)
    Cube(getsavefolder(s, true))
end

function rmcube(s)
    p = getsavefolder(s, true)
    if isfile(p) || isdir(p)
        rm(p, recursive = true)
    end
end
