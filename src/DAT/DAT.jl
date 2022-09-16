module DAT
using DocStringExtensions
import ..Cubes
using ..YAXTools
using Distributed:
    nworkers,
    pmap,
    @everywhere,
    workers,
    remotecall_fetch,
    myid,
    nprocs,
    remotecall, 
    @spawn, 
    AbstractWorkerPool, 
    default_worker_pool
import ..Cubes: cubechunks, iscompressed, chunkoffset, CubeAxis, YAXArray, caxes, YAXSlice
import ..Cubes.Axes:
    AxisDescriptor, axname, ByInference, axsym, getOutAxis, getAxis, findAxis, match_axis
import ..Datasets: Dataset, createdataset
import ...YAXArrays
import ...YAXArrays.workdir
import YAXArrayBase
import ProgressMeter: Progress, next!, progress_pmap, progress_map
using YAXArrayBase
using DiskArrays: grid_offset, approx_chunksize, max_chunksize, RegularChunks, 
  IrregularChunks, GridChunks, eachchunk, ChunkType
using OffsetArrays: OffsetArray
using Dates

export mapCube,
    getAxis,
    InDims,
    OutDims,
    Dataset,
    CubeTable,
    cubefittable,
    fittable,
    MovingWindow

global const debugDAT = [false]

const WindowDescriptor = Tuple{Int,Int}

#TODO use a logging package
macro debug_print(e)
    debugDAT[1] && return (:(println($e)))
    :()
end

include("registration.jl")

"""
Internal representation of an input cube for DAT operations
    $(FIELDS)
"""
mutable struct InputCube{N}
    "The input data"
    cube::Any
    "The input description given by the user/registration"
    desc::InDims
    "List of axes that were actually selected through the description"
    axesSmall::Vector
    icolon::Vector{Int}
    colonperm::Union{Vector{Int},Nothing}
    "Indices of loop axes that this cube does not contain, i.e. broadcasts"
    loopinds::Vector{Int}
    "Number of elements to keep in cache along each axis"
    cachesize::Vector{Int}     # TODO: delete

    window::Vector{WindowDescriptor}
    iwindow::Vector{Int}
    windowloopinds::Vector{Int}
    iall::Vector{Int}
end

function InputCube(c, desc::InDims)
    internalaxes = findAxis.(desc.axisdesc, Ref(c))
    any(isequal(nothing), internalaxes) &&
        error("One of the input axes not found in input cubes")
    fullaxes = internalaxes[findall(i -> !isa(i, MovingWindow), desc.axisdesc)]
    axlist = caxes(c)
    axesSmall = map(i -> axlist[i], fullaxes)
    colonperm =
        issorted(internalaxes) ? nothing :
        collect(Base.invperm(sortperm(collect(internalaxes))))
    _window = findall(i -> isa(i, MovingWindow), desc.axisdesc)
    iwindow = collect(internalaxes[_window])
    window =
        WindowDescriptor[(desc.axisdesc[i].pre, desc.axisdesc[i].after) for i in _window]
    InputCube{ndims(c)}(
        c,
        desc,
        collect(CubeAxis, axesSmall),
        collect(fullaxes),
        colonperm,
        Int[],
        Int[],
        window,
        iwindow,
        Int[],
        collect(internalaxes),
    )
end
geticolon(ic::InputCube) = ic.icolon
getwindowoob(ic::InputCube) = ic.desc.window_oob_value
createworkarrays(T, s, ntr) = [Array{T}(undef, s...) for i = 1:ntr]
getwindow(ic::InputCube) = zip(ic.windowloopinds, ic.window)
function getworksize(ic::InputCube{N}) where {N}
    r = map(ic.iall) do i
        i1 = findfirst(isequal(i), ic.icolon)
        i1 === nothing || return size(ic.cube, i)
        i2 = findfirst(isequal(i), ic.iwindow)
        return sum(ic.window[i2]) + 1
    end
    (r...,)
end




"""
Internal representation of an output cube for DAT operations
## Fields
    $(FIELDS)
"""
mutable struct OutputCube
    "The actual outcube cube, once it is generated"
    cube::Any
    "The unpermuted output cube"
    cube_unpermuted::Any
    "The description of the output axes as given by users or registration"
    desc::OutDims
    "The list of output axes determined through the description"
    axesSmall::Array{CubeAxis}
    "List of all the axes of the cube"
    allAxes::Vector{CubeAxis}
    "Index of the loop axes that are broadcasted for this output cube"
    loopinds::Vector{Int}
    innerchunks::Any
    "Elementtype of the outputcube"
    outtype::Any
end
getwindow(::OutputCube) = []

const InOutCube = Union{InputCube,OutputCube}


getsmallax(c::InOutCube) = c.axesSmall
geticolon(c::OutputCube) = 1:length(c.axesSmall)
getAxis(desc, c::InOutCube) = getAxis(desc, c.cube)

has_window(c::InOutCube) = !isempty(getwindow(c))
function getworksize(oc::OutputCube)
    (length.(oc.axesSmall)...,)
end


function getworkarray(c::InOutCube, ntr)
    wa = createworkarrays(eltype(c.cube), getworksize(c), ntr)
    map(wa) do w
        if !has_window(c)
            wrapWorkArray(c.desc.artype, w, c.axesSmall)
        else
            axes = map(c.iall) do i
                i1 = findfirst(isequal(i), c.icolon)
                i1 === nothing || return caxes(c.cube)[c.icolon[i1]]
                i2 = findfirst(isequal(i), c.iwindow)
                RangeAxis(axname(caxes(c.cube)[c.iwindow[i2]]), UnitRange(-c.window[i2][1], c.window[i2][2]))
            end
            wrapWorkArray(c.desc.artype, w, axes)
        end
    end
end

function interpretoutchunksizes(desc, axesSmall, incubes)
    if desc.chunksize == :max
        map(ax -> axname(ax) => RegularChunks(length(ax),0,length(ax)), axesSmall)
    elseif desc.chunksize == :input
        map(axesSmall) do ax
            for cc in incubes
                i = findAxis(axname(ax), cc)
                if i !== nothing
                    return axname(ax) => eachchunk(cc.data).chunks[i]
                end
            end
            return axname(ax) => length(ax)
        end
    else
        desc.chunksize
    end
end

getOutAxis(desc::Tuple, inAxes, incubes, pargs, f) =
    map(i -> getOutAxis(i, inAxes, incubes, pargs, f), desc)
function OutputCube(desc::OutDims, inAxes, incubes, pargs, f)
    axesSmall = getOutAxis(desc.axisdesc, inAxes, incubes, pargs, f)
    outtype = getOuttype(desc.outtype, incubes)
    innerchunks = interpretoutchunksizes(desc, axesSmall, incubes)
    OutputCube(
        nothing,
        nothing,
        desc,
        collect(CubeAxis, axesSmall),
        CubeAxis[],
        Int[],
        innerchunks,
        outtype,
    )
end

"""
Configuration object of a DAT process. This holds all necessary information to perform the calculations.
It contains the following fields:
$TYPEDFIELDS
"""
mutable struct DATConfig{NIN,NOUT}
    "The input data cubes"
    incubes::NTuple{NIN,InputCube}
    "The output data cubes"
    outcubes::NTuple{NOUT,OutputCube}
    "List of all axes of the input cubes"
    allInAxes::Vector
    "List of axes that are looped through"
    LoopAxes::Vector
    "Flag whether the computation is parallelized"
    ispar::Bool
    ""
    loopcachesize::Vector{Int}
    ""
    allow_irregular_chunks::Bool
    "Maximal size of the in memory cache"
    max_cache::Any
    "Inner function which is computed"
    fu::Any
    "Flag whether the computation happens in place"
    inplace::Bool
    ""
    include_loopvars::Bool
    ""
    ntr::Any
    "Additional arguments for the inner function"
    addargs::Any
    "Additional keyword arguments for the inner function"
    kwargs::Any
end
function DATConfig(
    cdata,
    indims,
    outdims,
    inplace,
    max_cache,
    fu,
    ispar,
    include_loopvars,
    allow_irregular,
    nthreads,
    addargs,
    kwargs,
)

    isa(indims, InDims) && (indims = (indims,))
    isa(outdims, OutDims) && (outdims = (outdims,))
    length(cdata) == length(indims) || error(
        "Number of input cubes ($(length(cdata))) differs from registration ($(length(indims)))",
    )
    incubes = ([InputCube(o[1], o[2]) for o in zip(cdata, indims)]...,)
    allInAxes = vcat([ic.axesSmall for ic in incubes]...)
    outcubes = ((
        map(1:length(outdims), outdims) do i, desc
            OutputCube(desc, allInAxes, cdata, addargs, fu)
        end
    )...,)

    DATConfig(
        incubes,
        outcubes,
        allInAxes,
        CubeAxis[],                                 # LoopAxes
        ispar,
        Int[],
        allow_irregular,
        max_cache,                                  # max_cache
        fu,                                         # fu                                      # loopcachesize
        inplace,                                    # inplace
        include_loopvars,
        nthreads,
        addargs,                                    # addargs
        kwargs,
    )
end

"""
    getOuttype(outtype, cdata)
# Internal function 
Get the element type for the output cube
"""
getOuttype(outtype::Int, cdata) = eltype(cdata[outtype])
function getOuttype(outtype::DataType, cdata)
    outtype
end

mapCube(fu::Function, cdata, addargs...; kwargs...) =
    mapCube(fu, (cdata,), addargs...; kwargs...)


"""
    mapCube(fun, cube, addargs...;kwargs...)

    Map a given function `fun` over slices of all cubes of the dataset `ds`. 
    Use InDims to discribe the input dimensions and OutDims to describe the output dimensions of the function.
    For Datasets, only one output cube can be specified.
    In contrast to the mapCube function for cubes, additional arguments for the inner function should be set as keyword arguments.

    For the specific keyword arguments see the docstring of the mapCube function for cubes.
"""        
function mapCube(
    f,
    in_ds::Dataset,
    addargs...;
    indims = InDims(),
    outdims = OutDims(),
    inplace = true,
    kwargs...,
)
    allars = values(in_ds.cubes)
    allaxes = collect(values(in_ds.axes))
    arnames = keys(in_ds.cubes)
    sarnames = (arnames...,)
    any(ad -> findAxis(ad, allaxes) === nothing, indims.axisdesc) &&
        error("One of the Dimensions does not exist in Dataset")

    idar = collect(indims.axisdesc)
    allindims = map(allars) do c
        idshort = filter(idar) do ad
            findAxis(ad, c) !== nothing
        end
        InDims((idshort...,), indims.artype, indims.procfilter)
    end
    isa(outdims, OutDims) || error("Only one output cube currently supported for datasets")
    isempty(addargs) || error(
        "Additional arguments currently not supported for datasets, use kwargs instead",
    )
    if inplace
        # Why do we specify arnames here again, this seems to be unused in the let block?
        fnew = let arnames = collect(arnames), f = f
            function dsfun(xout, xin...; kwargs...)
                incubes = NamedTuple{sarnames,typeof(xin)}(xin)
                f(xout, incubes; kwargs...)
            end
        end
    else
        fnew = let arnames = collect(arnames), f = f
            function dsfun(xin...; kwargs...)
                incubes = NamedTuple{sarnames,typeof(xin)}(xin)
                f(incubes; kwargs...)
            end
        end
    end
    allcubes = collect(values(in_ds.cubes))
    mapCube(
        fnew,
        (allcubes...,);
        indims = allindims,
        outdims = outdims,
        inplace = inplace,
        kwargs...,
    )
end

import Base.mapslices
function mapslices(f, d::Union{YAXArray,Dataset}, addargs...; dims, kwargs...)
    isa(dims, String) && (dims = (dims,))
    mapCube(
        f,
        d,
        addargs...;
        indims = InDims(dims...),
        outdims = OutDims(ByInference()),
        inplace = false,
        kwargs...,
    )
end



"""
    mapCube(fun, cube, addargs...;kwargs...)

Map a given function `fun` over slices of the data cube `cube`. 
    The additional arguments `addargs` will be forwarded to the inner function `fun`.
    Use InDims to discribe the input dimensions and OutDims to describe the output dimensions of the function.
### Keyword arguments

* `max_cache=YAXDefaults.max_cache` maximum size of blocks that are read into memory, defaults to approx 10Mb
* `indims::InDims` List of input cube descriptors of type [`InDims`](@ref) for each input data cube
* `outdims::OutDims` List of output cube descriptors of type [`OutDims`](@ref) for each output cube
* `inplace` does the function write to an output array inplace or return a single value> defaults to `true`
* `ispar` boolean to determine if parallelisation should be applied, defaults to `true` if workers are available.
* `showprog` boolean indicating if a ProgressMeter shall be shown
* `include_loopvars` boolean to indicate if the varoables looped over should be added as function arguments
* `nthreads` number of threads for the computation, defaults to Threads.nthreads for every worker.
* `loopchunksize` determines the chunk sizes of variables which are looped over, a dict
* `kwargs` additional keyword arguments are passed to the inner function

The first argument is always the function to be applied, the second is the input cube or
a tuple of input cubes if needed.
"""
function mapCube(
    fu::Function,
    cdata::Tuple,
    addargs...;
    max_cache = YAXArrays.YAXDefaults.max_cache[],
    indims = InDims(),
    outdims = OutDims(),
    inplace = true,
    ispar = nprocs() > 1,
    debug = false,
    include_loopvars = false,
    showprog = true,
    irregular_loopranges = false, 
    nthreads = ispar ? Dict(i => remotecall_fetch(Threads.nthreads, i) for i in workers()) :
               [Threads.nthreads()],
    loopchunksize = Dict(),
    kwargs...,
)

    #Translate slices
    if any(i -> isa(i, YAXSlice), cdata)
        inew = map(cdata) do d
            isa(d, YAXSlice) ? InDims(axname.(d.sliceaxes[2])...) : InDims()
        end
        cnew = map(i -> isa(i, YAXSlice) ? i.c : i, cdata)
        return mapCube(
            fu,
            cnew,
            addargs...;
            indims = inew,
            outdims = outdims,
            inplace = inplace,
            ispar = ispar,
            debug = debug,
            include_loopvars = include_loopvars,
            irregular_loopranges = irregular_loopranges,
            showprog = showprog,
            nthreads = nthreads,
            kwargs...,
        )
    end
    @debug_print "Generating DATConfig"
    dc = DATConfig(
        cdata,
        indims,
        outdims,
        inplace,
        max_cache,
        fu,
        ispar,
        include_loopvars,
        irregular_loopranges,
        nthreads,
        addargs,
        kwargs,
    )
    @debug_print "Analysing Axes"
    analyzeAxes(dc)
    @debug_print "Permuting loop axes"
    permuteloopaxes(dc)
    @debug_print "Calculating Cache Sizes"
    getCacheSizes(dc, loopchunksize)
    @debug_print "Generating Output Cube"
    generateOutCubes(dc)
    @debug_print "Running main Loop"
    debug && return (dc)
    runLoop(dc, showprog)
    @debug_print "Finalizing Output Cube"

    if length(dc.outcubes) == 1
        return dc.outcubes[1].cube_unpermuted
    else
        return (map(i -> i.cube_unpermuted, dc.outcubes)...,)
    end

end

function makeinplace(f)
    (args...; kwargs...) -> begin
        first(args) .= f(Base.tail(args)...; kwargs...)
        nothing
    end
end

to_chunksize(c::RegularChunks, cs, _ = true) = RegularChunks(cs, c.offset, c.s)
function to_chunksize(c::IrregularChunks, cs, allow_irregular=true)
    fac = cs ÷ approx_chunksize(c)
    ll = length.(c)
    newchunks = sum.(Iterators.partition(ll,fac))
    if length(newchunks)==1 
        RegularChunks(cs, 0, newchunks[1])
    elseif length(newchunks) == 2 || all(==(cs),newchunks[2:end-1])
        RegularChunks(cs, cs-newchunks[1], sum(newchunks))
    else
        if allow_irregular
            IrregularChunks(chunksizes = newchunks)
        else
            RegularChunks(cs, 0, last(last(c)))
        end
    end
end

"""
    getloopchunks(dc::DATConfig)
# Internal function
    Returns the chunks that can be looped over toghether for all dimensions.
    This computation of the size of the chunks is handled by [`DiskArrays.approx_chunksize`](@ref)
"""
function getloopchunks(dc::DATConfig)
    lc = dc.loopcachesize
    co = map(lc,dc.LoopAxes) do cs, ax
        allchunks = map(dc.incubes) do ic
            ii = findAxis(ax, caxes(ic.cube))
            ii === nothing ? nothing : eachchunk(ic.cube.data).chunks[ii]
        end
        allchunks = unique(filter(!isnothing, allchunks))
        if length(allchunks) == 1
            return to_chunksize(allchunks[1],cs,dc.allow_irregular_chunks)
        end
        allchunks_offset = filter(i->mod(cs,approx_chunksize(i))==0, allchunks)
        allchunks = isempty(allchunks_offset) ? allchunks : allchunks_offset
        if length(allchunks) == 1
            return to_chunksize(allchunks[1],cs,dc.allow_irregular_chunks)
        end
        if !dc.allow_irregular_chunks
            allchunks = filter(i->isa(i,RegularChunks),allchunks)
        end
        if length(allchunks) == 1
            return to_chunksize(allchunks[1],cs)
        end
        allchunks = to_chunksize.(allchunks,cs)
        allchunks = unique(allchunks)
        if length(allchunks)>1
            @warn "Multiple chunk offset resolutions possible: $allchunks for dim $(axname(ax))"
        end
        first(allchunks)
    end
    (co...,)
end

"""
    permuteloopaxes(dc)
# Internal function
Permute the dimensions of the cube, so that the axes that are looped through are in the first positions.
This is necessary for a faster looping through the data.
"""
function permuteloopaxes(dc)
    foreach(dc.incubes) do ic
        if !issorted(ic.loopinds)
            p = sortperm(ic.loopinds)
            ic.cube = permutedims(ic.cube,[1:length(ic.axesSmall);p .+ length(ic.axesSmall)])
            ic.loopinds = ic.loopinds[p]
        end
    end
end

updatears(clist, r, f, caches) =
    foreach(clist, caches) do ic, ca
        if !has_window(ic)
            updatear(f, r, ic.cube, geticolon(ic), ic.loopinds, ca)
        else
            updatear_window(
                r,
                ic.cube,
                geticolon(ic),
                ic.loopinds,
                ca,
                zip(ic.iwindow, ic.window),
                getwindowoob(ic),
            )
        end
    end
getindsall(indscol, loopinds, rfunc, colfunc = _ -> Colon()) =
    getindsall((), 1, (sort(indscol)...,), (loopinds...,), rfunc, colfunc)
function getindsall(indsall, inow, indscol, loopinds, rfunc, colfunc)
    if !isempty(indscol) && first(indscol) == inow
        getindsall(
            (indsall..., colfunc(inow)),
            inow + 1,
            Base.tail(indscol),
            loopinds,
            rfunc,
            colfunc,
        )
    else
        getindsall(
            (indsall..., rfunc(first(loopinds))),
            inow + 1,
            indscol,
            Base.tail(loopinds),
            rfunc,
            colfunc,
        )
    end
end
getindsall(indsall, inow, ::Tuple{}, ::Tuple{}, r, c) = indsall

function updatear_window(r, cube, indscol, loopinds, cache, windows, windowoob)
    indsall = getindsall(indscol, loopinds, i -> r[i])
    for (iw, pa) in windows
        iold = indsall[iw]
        indsall = Base.setindex(indsall, first(iold)-pa[1]:last(iold)+pa[2], iw)
    end
    data = getdata(cube)
    l2 = map((i, s) -> isa(i, Colon) ? s : length(i), indsall, size(cache))
    oo = map(indsall, axes(cache), axes(data)) do i, c, d
        if isa(i, Colon)
            return Base.OneTo(length(c)), Base.OneTo(length(c))
        else
            precut, aftercut = max(0, first(d) - first(i)), max(0, last(i) - last(d))
            icube = first(i)+precut:last(i)-aftercut
            icache = first(c)+precut:first(c)+precut+length(icube)-1
            return icache, icube
        end
    end
    hinds = first.(oo)
    indsall2 = last.(oo)
    fill!(cache, windowoob)
    cache[hinds...] = data[indsall2...]
end

function updatear(f, r, cube, indscol, loopinds, cache)
    indsall = getindsall(indscol, loopinds, i -> r[i])
    l2 = map((i, s) -> isa(i, Colon) ? s : length(i), indsall, size(cache))
    if size(cache) != l2
        hinds = map((i, s) -> isa(i, Colon) ? (1:s) : 1:length(i), indsall, size(cache))
        if f == :read
            cache[hinds...] = getdata(cube)[indsall...]
        else
            getdata(cube)[indsall...] = cache[hinds...]
        end
    else
        if f == :read
            d = getdata(cube)[indsall...]
            cache[:] = d
        else
            _writedata(getdata(cube), cache, indsall)
        end
    end
end
_writedata(d,cache,indsall) = d[indsall...] = cache
_writedata(d::Array{<:Any,0},cache::Array{<:Any,0},::Tuple{}) = d[] = cache[]


updateinars(dc, r, incaches) = updatears(dc.incubes, r, :read, incaches)
writeoutars(dc, r, outcaches) = updatears(dc.outcubes, r, :write, outcaches)

function pmap_with_data(f, p::AbstractWorkerPool, c...; initfunc, progress=nothing, kwargs...)
    d = Dict(ip=>remotecall(initfunc, ip) for ip in workers(p))
    allrefs = @spawn d
    function fnew(args...,)
        refdict = fetch(allrefs)
        myargs = fetch(refdict[myid()])
        f(args..., myargs)
    end
    if progress !==nothing
        progress_pmap(fnew,p,c...;progress=progress,kwargs...)
    else
        pmap(fnew,p,c...;kwargs...)
    end
end
pmap_with_data(f,c...;initfunc,kwargs...) = pmap_with_data(f,default_worker_pool(),c...;initfunc,kwargs...) 

function moduleloadedeverywhere()
    try
        isloaded = map(workers()) do w
            #We try calling a function defined inside this module, thi will error when YAXArrays is not loaded on the remote workers
            remotecall(() -> true, w)
        end
        fetch.(isloaded)
    catch e
        return false
    end
    return true
end

function runLoop(dc::DATConfig, showprog)
    allRanges = GridChunks(getloopchunks(dc)...)
    if dc.ispar
        #Test if YAXArrays is loaded on all workers:
        moduleloadedeverywhere() || error(
            "YAXArrays is not loaded on all workers. Please run `@everywhere using YAXArrays` to fix.",
        )
        dcref = @spawn dc
        prepfunc = ()->getallargs(fetch(dcref))
        prog = showprog ? Progress(length(allRanges)) : nothing
        pmap_with_data(allRanges, initfunc=prepfunc, progress=prog) do r, prep
            incaches, outcaches, args = prep
            updateinars(dc, r, incaches)
            innerLoop(r, args...)
            writeoutars(dc, r, outcaches)
        end
    else
        incaches, outcaches, args = getallargs(dc)
        mapfun = showprog ? progress_map : map
        mapfun(allRanges) do r
            updateinars(dc, r, incaches)
            innerLoop(r, args...)
            writeoutars(dc, r, outcaches)
        end
    end
    dc.outcubes
end

abstract type AxValCreator end
struct NoLoopAxes <: AxValCreator end
struct AllLoopAxes{S,V} <: AxValCreator
    loopsyms::S
    loopaxvals::V
end
AllLoopAxes(a) = AllLoopAxes(map(axsym, a), map(i -> i.values, a))
getlaxvals(::NoLoopAxes, cI, offscur) = ()
getlaxvals(a::AllLoopAxes, cI, offscur) = (
    NamedTuple{a.loopsyms}(
        map((ax, i, of) -> (i + of, ax[i+of]), a.loopaxvals, cI.I, offscur),
    ),
)


function getallargs(dc::DATConfig)
    incache, outcache = getCubeCache(dc)
    filters = map(ic -> ic.desc.procfilter, dc.incubes)
    inworkar, outworkar = generateworkarrays(dc)
    axvals = if dc.include_loopvars
        lax = (dc.LoopAxes...,)
        AllLoopAxes(lax)
    else
        NoLoopAxes()
    end
    adda = dc.addargs
    kwa = dc.kwargs
    fu = if !dc.inplace
        makeinplace(dc.fu)
    else
        dc.fu
    end
    inarsbc = map(dc.incubes, incache) do ic, cache
        allax = getindsall(geticolon(ic), 1:length(dc.LoopAxes), i -> i in ic.loopinds ? true : false)
        if has_window(ic)
            for (iw, pa) in zip(ic.iwindow, ic.window)
                allax = Base.setindex(allax, pa, iw)
            end
        end
        if ic.colonperm === nothing
            pa = PickAxisArray(cache, allax)
        else
            pa = PickAxisArray(cache, allax, ic.colonperm)
        end
    end
    outarsbc = map(dc.outcubes, outcache) do oc, cache
        allax = getindsall(1:length(oc.axesSmall), oc.loopinds, i -> true)
        pa = PickAxisArray(cache, allax)
        pa
    end
    incache,
    outcache,
    (fu, inarsbc, outarsbc, filters, inworkar, outworkar, axvals, adda, kwa)
end


function getbackend(oc, ispar, max_cache)
    elementtype = Union{oc.outtype,Missing}
    outsize =
        sizeof(elementtype) * (length(oc.allAxes) > 0 ? prod(map(length, oc.allAxes)) : 1)
    rt = oc.desc.backend
    if rt == :auto
        if ispar[] || outsize > max_cache
            rt = :zarr
        else
            rt = :array
        end
    end
    b = YAXArrayBase.backendlist[Symbol(rt)]
    if !allow_parallel_write(b)
        ispar[] = false
    end
    elementtype, b
end

function generateOutCube(
    ::Type{T},
    elementtype,
    oc::OutputCube,
    loopcachesize,
    co;
    kwargs...,
) where {T}
    cs_inner = (map(length, oc.axesSmall)...,)
    cs = (cs_inner..., loopcachesize...)
    co = (map(_->0, oc.axesSmall)...,co...)
    for (i, cc) in enumerate(oc.innerchunks)
        if cc !== nothing && i <= length(oc.axesSmall)
            cs = Base.setindex(cs, approx_chunksize(cc), i)
            co = Base.setindex(co,grid_offset(cc), i)
        end
    end
    cube1, cube2 = createdataset(
        T,
        oc.allAxes;
        T = elementtype,
        chunksize = cs,
        chunkoffset = co,
        kwargs...,
    )
    oc.cube = cube1
    oc.cube_unpermuted = cube2
end
function generateOutCube(
    ::Type{T},
    elementtype,
    oc::OutputCube,
    loopcachesize,
    co;
    kwargs...,
) where {T<:Array}
    newsize = map(length, oc.allAxes)
    outar = Array{elementtype}(undef, newsize...)
    fill!(outar,_zero(elementtype))
    oc.cube = YAXArray(oc.allAxes, outar)
    oc.cube_unpermuted = oc.cube
end
_zero(T) = zero(T)
_zero(T::Type{<:AbstractString}) = convert(T, "")


function generateOutCubes(dc::DATConfig)
    rr = getloopchunks(dc)
    cs = approx_chunksize.(rr)
    offs = grid_offset.(rr)
    foreach(dc.outcubes) do c
        generateOutCube(c, Ref(dc.ispar), dc.max_cache, cs, offs)
    end
end
function generateOutCube(oc::OutputCube, ispar::Ref{Bool}, max_cache, loopcachesize, co)
    elementtype, cubetype = getbackend(oc, ispar, max_cache)
    generateOutCube(cubetype, elementtype, oc, loopcachesize, co; oc.desc.backendargs...)
end

function getCubeCache(dc::DATConfig)
    allranges = getloopchunks(dc)
    outcaches = map(i -> allocatecachebuf(i, max_chunksize.(allranges)), dc.outcubes)
    incaches = map(i -> allocatecachebuf(i, max_chunksize.(allranges)), dc.incubes)
    incaches, outcaches
end

function allocatecachebuf(ic::Union{InputCube,OutputCube}, loopcachesize)
    s = size(ic.cube)
    indsall = getindsall(geticolon(ic), ic.loopinds, i -> loopcachesize[i], i -> s[i])
    if has_window(ic)
        indsall = Base.OneTo.(indsall)
        for (iw, (pre, after)) in zip(ic.iwindow, ic.window)
            old = indsall[iw]
            new = (first(old)-pre):(last(old)+after)
            indsall = Base.setindex(indsall, new, iw)
        end
        #@show indsall
        OffsetArray(Array{eltype(ic.cube)}(undef, length.(indsall)...), indsall...)
    else
        Array{eltype(ic.cube)}(undef,indsall...)
    end
end

function init_DATworkers()
    freshworkermodule()
end

function analyzeAxes(dc::DATConfig{NIN,NOUT}) where {NIN,NOUT}

    loopaxsyms = Symbol[]
    for cube in dc.incubes
        for (iax,a) in enumerate(caxes(cube.cube))
            if !in(a, cube.axesSmall)
                s = axsym(a)
                is = findfirst(isequal(s), loopaxsyms) 
                if is === nothing
                    push!(dc.LoopAxes, a)
                    push!(loopaxsyms, s)
                    is = length(loopaxsyms)
                else
                    a == dc.LoopAxes[is] || error("Axes $a and $(dc.LoopAxes[is]) have the same name but are note identical")
                end
                push!(cube.loopinds,is)
                if iax in cube.iwindow
                    push!(cube.windowloopinds, is)
                end
            end
        end
    end
    for outcube in dc.outcubes
        LoopAxesAdd = CubeAxis[]
        for (il, loopax) in enumerate(dc.LoopAxes)
            push!(outcube.loopinds, il)
            push!(LoopAxesAdd, loopax)
        end
        outcube.allAxes = CubeAxis[outcube.axesSmall; LoopAxesAdd]
        dold = outcube.innerchunks
        newchunks = ntuple(_->nothing, length(outcube.allAxes))
        for (k, v) in dold
            ii = findAxis(k, outcube.allAxes)
            if ii !== nothing
                if v isa Integer
                    v = RegularChunks(v,0,length(outcube.allAxes[ii]))
                end
                newchunks = Base.setindex(newchunks, v, ii)
            end
        end
        outcube.innerchunks = newchunks
    end
    #And resolve names in chunk size dicts
    return dc
end

mysizeof(x) = sizeof(x)
mysizeof(x::Type{String}) = 1

"""
Function that compares two cache miss specifiers by their importance
"""
function cmpcachmisses(x1, x2)
    #First give preference to compressed misses
    if xor(x1.iscompressed, x2.iscompressed)
        return x1.iscompressed
        #Now compare the size of the miss multiplied with the inner size
    else
        return approx_chunksize(x1.cs) * x1.innerleap > approx_chunksize(x2.cs) * x2.innerleap
    end
end

function getCacheSizes(dc::DATConfig, loopchunksizes)

    inAxlengths = Vector{Int}[Int.(length.(cube.axesSmall)) for cube in dc.incubes]
    inblocksizes = map(
        (x, T) ->
            isempty(x) ? mysizeof(eltype(T.cube)) : prod(x) * mysizeof(eltype(T.cube)),
        inAxlengths,
        dc.incubes,
    )
    inblocksize = sum(inblocksizes)
    outblocksizes = map(
        C ->
            length(C.axesSmall) > 0 ?
            sizeof(C.outtype) * prod(map(Int ∘ length, C.axesSmall)) : 1,
        dc.outcubes,
    )
    outblocksize = length(outblocksizes) > 0 ? sum(outblocksizes) : 1
    #Now add cache miss information for each input cube to every loop axis
    cmisses = NamedTuple{
        (:iloopax, :cs, :iscompressed, :innerleap, :preventpar),
        Tuple{Int64,ChunkType,Bool,Int64,Bool},
    }[]
    userchunks = Dict{Int,Int}()
    for (k, v) in loopchunksizes
        ii = findAxis(k, dc.LoopAxes)
        if ii !== nothing
            v isa ChunkType || error("Loop chunks must be provided as ChunkType object")
            userchunks[ii] = v
        end
    end
    foreach(dc.LoopAxes, 1:length(dc.LoopAxes)) do lax, ilax
        haskey(userchunks, ilax) && return nothing
        for ic in dc.incubes
            #@show lax
            #@show ic.cube.axes
            ii = findAxis(lax, ic.cube)
            if !isa(ii, Nothing)
                inax = isempty(ic.axesSmall) ? 1 : prod(map(length, ic.axesSmall))
                push!(
                    cmisses,
                    (
                        iloopax = ilax,
                        cs = eachchunk(ic.cube.data).chunks[ii],
                        iscompressed = iscompressed(ic.cube),
                        innerleap = inax,
                        preventpar = false,
                    ),
                )
            end
        end
        for oc in dc.outcubes
            cs = oc.innerchunks
            ii = findAxis(lax, oc.allAxes)
            if !isa(ii, Nothing) && !isa(cs[ii], Nothing)
                innerleap = isempty(oc.axesSmall) ? 1 : prod(map(length, oc.axesSmall))
                push!(
                    cmisses,
                    (
                        iloopax = ilax,
                        cs = cs[ii],
                        iscompressed = iscompressed(oc.cube),
                        innerleap = innerleap,
                        preventpar = true,
                    ),
                )
            end
        end
    end
    cmisses = sort(unique(cmisses), lt = cmpcachmisses)
    loopcachesize, nopar = getLoopCacheSize(
        inblocksize + outblocksize,
        map(length, dc.LoopAxes),
        dc.max_cache,
        cmisses,
        userchunks,
    )
    # for cube in dc.incubes
    #     cube.cachesize = map(i->RegularChunks(length(i), 0, length(i)), cube.axesSmall)
    #     for (cs, loopAx) in zip(loopcachesize, dc.LoopAxes)
    #         in(axsym(loopAx), axsym.(caxes(cube.cube))) && push!(cube.cachesize, cs)
    #     end
    # end
    nopar && (dc.ispar = false)
    dc.loopcachesize = loopcachesize
    return dc
end

"Calculate optimal Cache size to DAT operation"
function getLoopCacheSize(preblocksize, loopaxlengths, max_cache, cmisses, userchunks)
    totcachesize = max_cache
    loopcachesize = ones(Int, length(loopaxlengths))
    #Go through user definitions
    incfac = totcachesize / preblocksize / prod(loopcachesize)
    incfac < 1 && error(
        "The requested slices do not fit into the specified cache. Please consider increasing max_cache",
    )
    # Go through list of cache misses first and decide
    imiss = 1
    while imiss <= length(cmisses)
        il = cmisses[imiss].iloopax
        s = min(approx_chunksize(cmisses[imiss].cs), loopaxlengths[il]) / loopcachesize[il]
        #Check if cache size is already set for this axis
        if loopcachesize[il] == 1
            if s < incfac
                loopcachesize[il] = min(approx_chunksize(cmisses[imiss].cs), loopaxlengths[il])
                incfac = totcachesize / preblocksize / prod(loopcachesize)
            else
                ii = floor(Int, incfac)
                
                while ii > 1 && rem(s, ii) != 0
                    ii = ii - 1
                end
                loopcachesize[il] = ii
                incfac = incfac/ii
                break
            end
        end
        imiss += 1
    end
    #Now second run to read multiple blocks at once
    if incfac >= 2
        for i = 1:length(loopcachesize)
            haskey(userchunks, i) && continue
            imul = min(floor(Int, incfac), loopaxlengths[i] ÷ loopcachesize[i])
            loopcachesize[i] = loopcachesize[i] * imul
            incfac = incfac / imul
            incfac < 2 && break
        end
    end
    if imiss < length(cmisses) + 1
        @warn "There are still cache misses"
        cmisses[imiss].iscompressed &&
            @warn "There are compressed caches misses, you may want to use a different cube chunking"
    else
        #TODO continue increasing cache sizes on by one...
    end
    nopar = any(i -> i.preventpar, cmisses[imiss:end])
    return loopcachesize, nopar
end

function distributeLoopRanges(block_size::NTuple{N,Int}, loopR::NTuple{N,Int}, co) where {N}
    allranges = map(block_size, loopR, co) do bs, lr, cocur
        collect(filter(!isempty, [max(1, i):min(i + bs - 1, lr) for i = (1-cocur):bs:lr]))
    end
    Iterators.product(allranges...)
end

function generateworkarrays(dc::DATConfig)
    inwork = map(i -> getworkarray(i, dc.ntr[myid()]), dc.incubes)
    outwork = map(i -> getworkarray(i, dc.ntr[myid()]), dc.outcubes)
    inwork, outwork
end

function innercode(
    f,
    cI,
    xinBC,
    xoutBC,
    filters,
    inwork,
    outwork,
    axvalcreator,
    offscur,
    addargs,
    kwargs,
)
    ithr = Threads.threadid()
    #Pick the correct array according to thread
    myinwork = map(i -> i[ithr], inwork)
    myoutwork = map(i -> i[ithr], outwork)
    #Copy data into work arrays
    foreach(myinwork, xinBC) do iw, x
        YAXArrayBase.getdata(iw) .= view(x, cI.I...)
    end
    #Apply filters
    mvs = map(docheck, filters, myinwork)
    if any(mvs)
        # Set all outputs to missing
        foreach(ow -> fill!(ow, missing), myoutwork)
    else
        #Compute loop axis values if necessary
        laxval = getlaxvals(axvalcreator, cI, offscur)
        #Finally call the function
        f(myoutwork..., myinwork..., laxval..., addargs...; kwargs...)
    end
    #Copy data into output array
    foreach((iw, x) -> view(x, cI.I...) .= YAXArrayBase.getdata(iw), myoutwork, xoutBC)
end

using DataStructures: OrderedDict
using Base.Cartesian
@noinline function innerLoop(
    loopRanges,
    f,
    xinBC,
    xoutBC,
    filters,
    inwork,
    outwork,
    axvalcreator,
    addargs,
    kwargs,
)
    offscur = map(i -> (first(i) - 1), loopRanges)
    if length(inwork[1]) == 1
        for cI in CartesianIndices(map(i -> 1:length(i), loopRanges))
            innercode(
                f,
                cI,
                xinBC,
                xoutBC,
                filters,
                inwork,
                outwork,
                axvalcreator,
                offscur,
                addargs,
                kwargs,
            )
        end
    else
        Threads.@threads for cI in CartesianIndices(map(i -> 1:length(i), loopRanges))
            innercode(
                f,
                cI,
                xinBC,
                xoutBC,
                filters,
                inwork,
                outwork,
                axvalcreator,
                offscur,
                addargs,
                kwargs,
            )
        end
    end
end


"Calculate an axis permutation that brings the wanted dimensions to the front"
function getFrontPerm(dc, dims)
    ax = caxes(dc)
    N = length(ax)
    perm = Int[i for i = 1:length(ax)]
    iold = Int[]
    for i = 1:length(dims)
        push!(iold, findAxis(dims[i], ax))
    end
    iold2 = sort(iold, rev = true)
    for i = 1:length(iold)
        splice!(perm, iold2[i])
    end
    perm = Int[iold; perm]
    return ntuple(i -> perm[i], N)
end

include("dciterators.jl")
include("tablestats.jl")
end
