module Datasets
import ..Cubes.Axes: axsym, axname, CubeAxis, findAxis, CategoricalAxis, RangeAxis, caxes
import ..Cubes: YAXArray, concatenatecubes, CleanMe
using ...YAXArrays: YAXArrays, YAXDefaults
using DataStructures: OrderedDict, counter
using Dates: Day, Hour, Minute, Second, Month, Year, Date, DateTime, TimeType
using IntervalSets: Interval, (..)
using CFTime: timedecode, timeencode, DateTimeNoLeap, DateTime360Day, DateTimeAllLeap
using YAXArrayBase
using YAXArrayBase: iscontdimval
using DiskArrayTools: CFDiskArray, ConcatDiskArray
using Glob: glob

export Dataset, Cube, open_dataset


struct Dataset
    cubes::OrderedDict{Symbol,YAXArray}
    axes::Dict{Symbol,CubeAxis}
end
function Dataset(; cubesnew...)
    axesall = Set{CubeAxis}()
    foreach(values(cubesnew)) do c
        ax = caxes(c)
        foreach(a -> push!(axesall, a), ax)
    end
    axesall = collect(axesall)
    axnameall = axsym.(axesall)
    axesnew = Dict{Symbol,CubeAxis}(axnameall[i] => axesall[i] for i = 1:length(axesall))
    Dataset(OrderedDict(cubesnew), axesnew)
end

function Base.show(io::IO, ds::Dataset)
    println(io, "YAXArray Dataset")
    println(io, "Dimensions: ")
    foreach(a -> println(io, "   ", a), values(ds.axes))
    print(io, "Variables: ")
    foreach(i -> print(io, i, " "), keys(ds.cubes))
end
function Base.propertynames(x::Dataset, private::Bool = false)
    if private
        Symbol[:cubes; :axes; collect(keys(x.cubes)); collect(keys(x.axes))]
    else
        Symbol[collect(keys(x.cubes)); collect(keys(x.axes))]
    end
end
function Base.getproperty(x::Dataset, k::Symbol)
    if k === :cubes
        return getfield(x, :cubes)
    elseif k === :axes
        return getfield(x, :axes)
    else
        x[k]
    end
end
Base.getindex(x::Dataset, i::Symbol) =
    haskey(x.cubes, i) ? x.cubes[i] :
    haskey(x.axes, i) ? x.axes[i] : throw(ArgumentError("$i not found in Dataset"))
function Base.getindex(x::Dataset, i::Vector{Symbol})
    cubesnew = [j => x.cubes[j] for j in i]
    Dataset(; cubesnew...)
end

function fuzzyfind(s::String, comp::Vector{String})
    sl = lowercase(s)
    f = findall(i -> startswith(lowercase(i), sl), comp)
    if length(f) != 1
        throw(KeyError("Name $s not found"))
    else
        f[1]
    end
end
function Base.getindex(x::Dataset, i::Vector{String})
    istr = string.(keys(x.cubes))
    ids = map(name -> fuzzyfind(name, istr), i)
    syms = map(j -> Symbol(istr[j]), ids)
    cubesnew = [Symbol(i[j]) => x.cubes[syms[j]] for j = 1:length(ids)]
    Dataset(; cubesnew...)
end
Base.getindex(x::Dataset, i::String) = getproperty(x, Symbol(i))
function subsetcube(x::Dataset; var = nothing, kwargs...)
    if var === nothing
        cc = x.cubes
        Dataset(; map(ds -> ds => subsetcube(cc[ds]; kwargs...), collect(keys(cc)))...)
    elseif isa(var, String) || isa(var, Symbol)
        subsetcube(getproperty(x, Symbol(var)); kwargs...)
    else
        cc = x[var].cubes
        Dataset(; map(ds -> ds => subsetcube(cc[ds]; kwargs...), collect(keys(cc)))...)
    end
end
function collectdims(g)
    dlist = Set{Tuple{String,Int,Int}}()
    varnames = get_varnames(g)
    foreach(varnames) do k
        d = get_var_dims(g, k)
        v = get_var_handle(g, k)
        for (len, dname) in zip(size(v), d)
            if !occursin("bnd", dname) && !occursin("bounds", dname)
                datts = get_var_attrs(g, dname)
                offs = get(datts, "_ARRAY_OFFSET", 0)
                push!(dlist, (dname, offs, len))
            end
        end
    end
    outd = Dict(d[1] => (ax = toaxis(d[1], g, d[2], d[3]), offs = d[2]) for d in dlist)
    length(outd) == length(dlist) ||
        throw(ArgumentError("All Arrays must have the same offset"))
    outd
end

function toaxis(dimname, g, offs, len)
    axname = dimname
    if !haskey(g, dimname)
        return RangeAxis(dimname, 1:len)
    end
    ar = get_var_handle(g, dimname)
    aratts = get_var_attrs(g, dimname)
    if uppercase(axname) == "TIME" && haskey(aratts, "units")
        tsteps = try
            timedecode(ar[:], aratts["units"], lowercase(get(aratts, "calendar", "standard")))
        catch
            ar[:]
        end
        RangeAxis(dimname, tsteps[offs+1:end])
    elseif haskey(aratts, "_ARRAYVALUES")
        vals = identity.(aratts["_ARRAYVALUES"])
        CategoricalAxis(axname, vals)
    else
        axdata = cleanaxiselement.(ar[offs+1:end])
        axdata = testrange(axdata)
        if eltype(axdata) <: AbstractString ||
           (!issorted(axdata) && !issorted(axdata, rev = true))
            CategoricalAxis(axname, axdata)
        else
            RangeAxis(axname, axdata)
        end
    end
end
propfromattr(attr) = Dict{String,Any}(filter(i -> i[1] != "_ARRAY_DIMENSIONS", attr))

#there are problems with saving custom string types to netcdf, so we clean this when creating the axis:
cleanaxiselement(x::AbstractString) = String(x)
cleanaxiselement(x::String) = x
cleanaxiselement(x) = x

"Test if data in x can be approximated by a step range"
function testrange(x)
    r = range(first(x), last(x), length = length(x))
    all(i -> isapprox(i...), zip(x, r)) ? r : x
end

function testrange(x::AbstractArray{<:Integer})
    steps = diff(x)
    if all(isequal(steps[1]), steps) && !iszero(steps[1])
        return range(first(x), step = steps[1], length(x))
    else
        return x
    end
end

testrange(x::AbstractArray{<:AbstractString}) = x

_glob(x) = startswith(x, "/") ? glob(x[2:end], "/") : glob(x)

open_mfdataset(g::AbstractString; kwargs...) = open_mfdataset(_glob(g); kwargs...)
open_mfdataset(g::Vector{<:AbstractString}; kwargs...) =
    merge_datasets(map(i -> open_dataset(i; kwargs...), g))

function open_dataset(g; driver = :all)
    g = to_dataset(g, driver = driver)
    isempty(get_varnames(g)) && throw(ArgumentError("Group does not contain datasets."))
    dimlist = collectdims(g)
    dnames = string.(keys(dimlist))
    varlist = filter(get_varnames(g)) do vn
        upname = uppercase(vn)
        !occursin("BNDS", upname) &&
            !occursin("BOUNDS", upname) &&
            !any(i -> isequal(upname, uppercase(i)), dnames)
    end
    allcubes = OrderedDict{Symbol,YAXArray}()
    for vname in varlist
        vardims = get_var_dims(g, vname)
        iax = [dimlist[vd].ax for vd in vardims]
        offs = [dimlist[vd].offs for vd in vardims]
        subs = if all(iszero, offs)
            nothing
        else
            ntuple(i -> (offs[i]+1):(offs[i]+length(iax[i])), length(offs))
        end
        ar = get_var_handle(g, vname)
        att = get_var_attrs(g, vname)
        if subs !== nothing
            ar = view(ar, subs...)
        end
        if !haskey(att, "name")
            att["name"] = vname
        end
        allcubes[Symbol(vname)] = YAXArray(iax, ar, propfromattr(att), cleaner = CleanMe[])
    end
    sdimlist = Dict(Symbol(k) => v.ax for (k, v) in dimlist)
    Dataset(allcubes, sdimlist)
end
Base.getindex(x::Dataset; kwargs...) = subsetcube(x; kwargs...)
YAXDataset(; kwargs...) = Dataset(YAXArrays.YAXDefaults.cubedir[]; kwargs...)


function Cube(ds::Dataset; joinname = "Variable")

    dl = collect(keys(ds.axes))
    dls = string.(dl)
    length(ds.cubes) == 1 && return first(values(ds.cubes))
    #TODO This is an ugly workaround to merge cubes with different element types,
    # There should bde a more generic solution
    eltypes = map(eltype, values(ds.cubes))
    majtype = findmax(counter(eltypes))[2]
    newkeys = Symbol[]
    for k in keys(ds.cubes)
        c = ds.cubes[k]
        if all(axn -> findAxis(axn, c) !== nothing, dls) && eltype(c) == majtype
            push!(newkeys, k)
        end
    end
    if length(newkeys) == 1
        return ds.cubes[first(newkeys)]
    else
        varax = CategoricalAxis(joinname, string.(newkeys))
        cubestomerge = [ds.cubes[k] for k in newkeys]
        foreach(
            i -> haskey(i.properties, "name") && delete!(i.properties, "name"),
            cubestomerge,
        )
        return concatenatecubes(cubestomerge, varax)
    end
end



"""
function createdataset(DS::Type,axlist; kwargs...)
  
  Creates a new datacube with axes specified in `axlist`. Each axis must be a subtype
  of `CubeAxis`. A new empty Zarr array will be created and can serve as a sink for
  `mapCube` operations.
  
  ### Keyword arguments
  
  * `folder=tempname()` location where the new cube is stored
  * `T=Union{Float32,Missing}` data type of the target cube
  * `chunksize = ntuple(i->length(axlist[i]),length(axlist))` chunk sizes of the array
  * `chunkoffset = ntuple(i->0,length(axlist))` offsets of the chunks
  * `persist::Bool=true` shall the disk data be garbage-collected when the cube goes out of scope?
  * `overwrite::Bool=false` overwrite cube if it already exists
  * `properties=Dict{String,Any}()` additional cube properties
  * `fillvalue= T>:Missing ? defaultfillval(Base.nonmissingtype(T)) : nothing` fill value
  * `datasetaxis="Variable"` special treatment of a categorical axis that gets written into separate zarr arrays
  """
function createdataset(
    DS,
    axlist;
    path = "",
    persist = nothing,
    T = Union{Float32,Missing},
    chunksize = ntuple(i -> length(axlist[i]), length(axlist)),
    chunkoffset = ntuple(i -> 0, length(axlist)),
    overwrite::Bool = false,
    properties = Dict{String,Any}(),
    datasetaxis = "Variable",
    kwargs...,
)
    if persist === nothing
        persist = !isempty(path)
    end
    path = getsavefolder(path, persist)
    check_overwrite(path, overwrite)
    splice_generic(x::AbstractArray, i) = [x[1:(i-1)]; x[(i+1:end)]]
    splice_generic(x::Tuple, i) = (x[1:(i-1)]..., x[(i+1:end)]...)
    myar = create_empty(DS, path)
    finalperm = nothing
    idatasetax = datasetaxis === nothing ? nothing : findAxis(datasetaxis, axlist)
    if idatasetax !== nothing
        groupaxis = axlist[idatasetax]
        axlist = splice_generic(axlist, idatasetax)
        chunksize = splice_generic(chunksize, idatasetax)
        chunkoffset = splice_generic(chunkoffset, idatasetax)
        finalperm =
            ((1:idatasetax-1)..., length(axlist) + 1, (idatasetax:length(axlist))...)
    else
        groupaxis = nothing
    end
    foreach(axlist, chunkoffset) do ax, co
        arrayfromaxis(myar, ax, co)
    end
    attr = properties
    s = map(length, axlist) .+ chunkoffset
    if all(iszero, chunkoffset)
        subs = nothing
    else
        subs = ntuple(length(axlist)) do i
            (chunkoffset[i]+1):(length(axlist[i].values)+chunkoffset[i])
        end
    end
    if groupaxis === nothing
        cubenames = ["layer"]
    else
        cubenames = groupaxis.values
    end
    cleaner = CleanMe[]
    persist || push!(cleaner, CleanMe(path, false))
    allcubes = map(cubenames) do cn
        axnames = map(axname, axlist)
        axlengths = map(i -> length(get_var_handle(myar, i)), axnames)
        v = if allow_missings(myar) || !(T >: Missing)
            add_var(myar, T, cn, axlengths, axnames, attr; chunksize = chunksize, kwargs...)
        else
            S = Base.nonmissingtype(T)
            if !haskey(attr, "missing_value")
                attr["missing_value"] = YAXArrayBase.defaultfillval(S)
            end
            v = add_var(
                myar,
                S,
                cn,
                axlengths,
                axnames,
                attr;
                chunksize = chunksize,
                kwargs...,
            )
            CFDiskArray(v, attr)
        end
        if subs !== nothing
            v = view(v, subs...)
        end
        YAXArray(axlist, v, propfromattr(attr), cleaner = cleaner)
    end
    if groupaxis === nothing
        return allcubes[1], allcubes[1]
    else
        cube = concatenatecubes(allcubes, groupaxis)
        return permutedims(cube, finalperm), cube
    end
end

function getsavefolder(name, persist)
    if isempty(name)
        name = persist ? [splitpath(tempname())[end]] : splitpath(tempname())[2:end]
        joinpath(YAXDefaults.workdir[], name...)
    else
        (occursin("/", name) || occursin("\\", name)) ? name :
        joinpath(YAXDefaults.workdir[], name)
    end
end

function check_overwrite(newfolder, overwrite)
    if isdir(newfolder) || isfile(newfolder)
        if overwrite
            rm(newfolder, recursive = true)
        else
            error(
                "$(newfolder) already exists, please pick another name or use `overwrite=true`",
            )
        end
    end
end

function arrayfromaxis(p, ax::CubeAxis, offs)
    data, attr = dataattfromaxis(ax, offs)
    attr["_ARRAY_OFFSET"] = offs
    za = add_var(p, data, axname(ax), (axname(ax),), attr)
    za
end

prependrange(r::AbstractRange, n) =
    n == 0 ? r : range(first(r) - n * step(r), last(r), length = n + length(r))
function prependrange(r::AbstractVector, n)
    if n == 0
        return r
    else
        step = r[2] - r[1]
        first = r[1] - step * n
        last = r[1] - step
        radd = range(first, last, length = n)
        return [radd; r]
    end
end

defaultcal(::Type{<:TimeType}) = "standard"
defaultcal(::Type{<:DateTimeNoLeap}) = "noleap"
defaultcal(::Type{<:DateTimeAllLeap}) = "allleap"
defaultcal(::Type{<:DateTime360Day}) = "360_day"

datetodatetime(vals::AbstractArray{<:Date}) = DateTime.(vals)
datetodatetime(vals) = vals
toaxistype(x) = x
toaxistype(x::Array{<:AbstractString}) = string.(x)
toaxistype(x::Array{String}) = x

function dataattfromaxis(ax::CubeAxis, n)
    prependrange(toaxistype(ax.values), n), Dict{String,Any}()
end

# function dataattfromaxis(ax::CubeAxis,n)
#     prependrange(1:length(ax.values),n), Dict{String,Any}("_ARRAYVALUES"=>collect(ax.values))
# end
function dataattfromaxis(ax::CubeAxis{T}, n) where {T<:TimeType}
    data = timeencode(datetodatetime(ax.values), "days since 1980-01-01", defaultcal(T))
    prependrange(data, n),
    Dict{String,Any}("units" => "days since 1980-01-01", "calendar" => defaultcal(T))
end

#The good old Cube function:
Cube(s::String; kwargs...) = Cube(open_dataset(s); kwargs...)
function Cube(; kwargs...)
    if !isempty(YAXArrays.YAXDefaults.cubedir[])
        Cube(YAXArrays.YAXDefaults.cubedir[]; kwargs...)
    else
        error("A path should be specified")
    end
end

#Defining joins of Datasets
abstract type AxisJoin end
struct AllEqual <: AxisJoin
    ax::Any
end
struct SortedRanges <: AxisJoin
    axlist::Any
    perm::Any
end
blocksize(x::AllEqual) = 1
blocksize(x::SortedRanges) = length(x.axlist)
getperminds(x::AllEqual) = 1:1
getperminds(x::SortedRanges) = x.perm
wholeax(x::AllEqual) = x.ax
wholeax(x::SortedRanges) = reduce(vcat, x.axlist[x.perm])
struct NewDim <: AxisJoin
    newax::Any
end
#Test for a range of categorical axes how to concatenate them
function analyse_axjoin_ranges(dimvallist)
    firstax = first(dimvallist)
    if all(isequal(firstax), dimvallist)
        return AllEqual(firstax)
    end
    revorder = if all(issorted, dimvallist)
        false
    elseif all(i -> issorted(i, rev = true), dimvallist)
        true
    else
        error("Dimension values are not sorted")
    end
    function ltfunc(ax1, ax2)
        min1, max1 = extrema(ax1)
        min2, max2 = extrema(ax2)
        if max1 < min2
            return true
        elseif min1 > max2
            return false
        else
            error("Dimension ranges overlap")
        end
    end
    sp = sortperm(dimvallist, rev = revorder, lt = ltfunc)
    SortedRanges(dimvallist, sp)
end
using YAXArrayBase: YAXArrayBase, getdata, getattributes, yaxcreate
function create_mergedict(dimvallist)
    allmerges = Dict{Symbol,Any}()

    for (axn, dimvals) in dimvallist
        iscont = iscontdimval.(dimvals)
        if all(iscont)
            allmerges[axn] = analyse_axjoin_ranges(dimvals)
        elseif any(iscont)
            error("Mix of continous and non-continous values")
        else
            allmerges[axn] = analyse_axjoin_categorical(dimvals)
        end
    end
    allmerges
end
function merge_datasets(dslist)
    allaxnames = counter(Symbol)
    for ds in dslist, k in keys(ds.axes)
        push!(allaxnames, k)
    end
    dimvallist = Dict(ax => map(i -> i.axes[ax].values, dslist) for ax in keys(allaxnames))
    allmerges = create_mergedict(dimvallist)
    repvars = counter(Symbol)
    for ds in dslist, v in keys(ds.cubes)
        push!(repvars, v)
    end
    tomergevars = filter(i -> i[2] == length(dslist), repvars)
    mergedvars = Dict{Symbol,Any}()
    for v in keys(tomergevars)
        dn = YAXArrayBase.dimnames(first(dslist)[v])
        howmerge = getindex.(Ref(allmerges), dn)
        sizeblockar = map(blocksize, howmerge)
        perminds = map(getperminds, howmerge)
        @assert length(dslist) == prod(sizeblockar)
        vcol = map(i -> getdata(i[v]), dslist)
        allatts =
            mapreduce(i -> getattributes(i[v]), merge, dslist, init = Dict{String,Any}())
        aa = [vcol[i] for (i, _) in enumerate(Iterators.product(perminds...))]
        dvals = map(wholeax, howmerge)
        mergedvars[v] = yaxcreate(YAXArray, ConcatDiskArray(aa), dn, dvals, allatts)
    end
    Dataset(; mergedvars...)
end


end
