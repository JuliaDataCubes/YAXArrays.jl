module Datasets
import ..Cubes.ESDLZarr: toaxis, axname, AbstractCubeData, ZArrayCube, propfromattr, subsetcube, caxes, concatenateCubes
import Zarr: ZGroup, zopen
import ..Cubes.Axes: axsym, CubeAxis, findAxis, CategoricalAxis, RangeAxis
import ..Cubes: AbstractCubeData, Cube, ESDLArray
import DataStructures: OrderedDict, counter
using NetCDF: NcFile

include("interface.jl")
include("zarr.jl")
include("netcdf.jl")

struct Dataset
    cubes::OrderedDict{Symbol,AbstractCubeData}
    axes::Dict{Symbol,CubeAxis}
end
function Dataset(;cubesnew...)
    axesall = Set{CubeAxis}()
    foreach(values(cubesnew)) do c
        ax = caxes(c)
        foreach(a->push!(axesall,a),ax)
    end
    axesall = collect(axesall)
    axnameall = [axsym(a) in (:Lon, :Lat, :Time) ? Symbol(lowercase(string(axsym(a)))) : axsym(a) for a in axesall]
    axesnew = Dict{Symbol,CubeAxis}(axnameall[i]=>axesall[i] for i in 1:length(axesall))
    Dataset(OrderedDict(cubesnew), axesnew)
end

function Base.show(io::IO,ds::Dataset)
    println(io,"ESDL Dataset")
    println(io,"Dimensions: ")
    foreach(a->println(io,"   ", a),values(ds.axes))
    print(io,"Variables: ")
    foreach(i->print(io,i," "),keys(ds.cubes))
end
function Base.propertynames(x::Dataset, private=false)
    if private
        Symbol[:cubes; :axes; keys(x.cubes); keys(x.axes)]
    else
        Symbol[collect(keys(x.cubes)); collect(keys(x.axes))]
    end
end
function Base.getproperty(x::Dataset,k::Symbol)
    if k === :cubes
        return getfield(x,:cubes)
    elseif k === :axes
        return getfield(x,:axes)
    else
        x[k]
    end
end
Base.getindex(x::Dataset,i::Symbol) = haskey(x.cubes, i) ? x.cubes[i] : haskey(x.axes,i) ? x.axes[i] : throw(ArgumentError("$i not found in Dataset"))
function Base.getindex(x::Dataset,i::Vector{Symbol})
    cubesnew = Dict{Symbol, AbstractCubeData}(j=>x.cubes[j] for j=i)
    Dataset(;cubesnew...)
end

function fuzzyfind(s::String,comp::Vector{String})
    sl = lowercase(s)
    f = findall(i->startswith(lowercase(i),sl),comp)
    if length(f) != 1
        throw(KeyError("Name $s not found"))
    else
        f[1]
    end
end
function Base.getindex(x::Dataset,i::Vector{String})
    istr = string.(keys(x.cubes))
    ids  = map(name->fuzzyfind(name,istr),i)
    syms   = map(j->Symbol(istr[j]),ids)
    cubesnew = Dict{Symbol, AbstractCubeData}(Symbol(i[j])=>x.cubes[syms[j]] for j=1:length(ids))
    Dataset(;cubesnew...)
end
Base.getindex(x::Dataset,i::String)=getproperty(x,Symbol(i))
function subsetcube(x::Dataset; var=nothing, kwargs...)
    if var ===nothing
        cc = x.cubes
        Dataset(;map(ds->ds=>subsetcube(cc[ds];kwargs...),collect(keys(cc)))...)
    elseif isa(var,String) || isa(var, Symbol)
        subsetcube(getproperty(x,Symbol(var));kwargs...)
    else
        cc = x[var].cubes
        Dataset(;map(ds->ds=>subsetcube(cc[ds];kwargs...),collect(keys(cc)))...)
    end
end
function collectdims(g::DatasetBackend)
  dlist = Set{Tuple{String,Int,Int}}()
  varnames = get_varnames(g)
  foreach(varnames) do k
    d = get_var_dims(g,k)
    v = get_var_handle(g,k)
    for (len,dname) in zip(size(v),d)
      if !occursin("bnd",dname) && !occursin("bounds",dname)
        datts = get_var_attrs(g,dname)
        offs = get(datts,"_ARRAY_OFFSET",0)
        push!(dlist,(dname,offs,len))
      end
    end
  end
  outd = Dict(d[1] => (ax = toaxis(d[1],g,d[2],d[3]), offs = d[2]) for d in dlist)
  length(outd)==length(dlist) || throw(ArgumentError("All Arrays must have the same offset"))
  outd
end

function toaxis(dimname,g,offs,len)
    axname = dimname
    if !haskey(g,dimname)
      return RangeAxis(dimname, 1:len)
    end
    ar = g[dimname]
    if axname=="Time" && haskey(ar.attrs,"units")
        tsteps = timedecode(ar[:],ar.attrs["units"],get(ar.attrs,"calendar","standard"))
        TimeAxis(tsteps[offs+1:end])
    elseif haskey(ar.attrs,"_ARRAYVALUES")
      vals = ar.attrs["_ARRAYVALUES"]
      CategoricalAxis(axname,vals)
    else
      axdata = testrange(ar[offs+1:end])
      RangeAxis(axname,axdata)
    end
end
propfromattr(attr) = filter(i->i[1]!=="_ARRAY_DIMENSIONS",attr)

"Test if data in x can be approximated by a step range"
function testrange(x)
  r = range(first(x),last(x),length=length(x))
  all(i->isapprox(i...),zip(x,r)) ? r : x
end

function Dataset(g::DatasetBackend)

  isempty(get_varnames(g)) && throw(ArgumentError("Zarr Group does not contain datasets."))
  dimlist = collectdims(g)
  dnames  = string.(keys(dimlist))
  varlist = filter(get_varnames(g)) do vn
    upname = uppercase(vn)
    !occursin("BNDS",upname) && !occursin("BOUNDS",upname) && !any(i->isequal(upname,uppercase(i)),dnames)
  end
  allcubes = OrderedDict{Symbol,AbstractCubeData}()
  for vname in  varlist
    vardims = get_var_dims(g,vname)
    iax = [dimlist[vd].ax for vd in vardims]
    offs = [dimlist[vd].offs for vd in vardims]
    subs = if all(iszero,offs)
      nothing
    else
      ntuple(i->(offs[i]+1):(offs[i]+length(iax[i])),length(offs))
    end
    ar = get_var_handle(g,vname)
    att = get_var_attrs(g,vname)
    allcubes[Symbol(vname)] = ESDLArray(iax,ar,propfromattr(att), cleaner=nothing)
  end
  sdimlist = Dict(Symbol(k)=>v.ax for (k,v) in dimlist)
  Dataset(allcubes,sdimlist)
end
Base.getindex(x::Dataset;kwargs...) = subsetcube(x;kwargs...)
Dataset(s::String;kwargs...) = Dataset(zopen(s);kwargs...)
ESDLDataset(;kwargs...) = Dataset(ESDL.ESDLDefaults.cubedir[];kwargs...)


function Cube(ds::Dataset; joinname="Variable")

  dl = collect(keys(ds.axes))
  dls = string.(dl)
  length(ds.cubes)==1 && return first(values(ds.cubes))
  #TODO This is an ugly workaround to merge cubes with different element types,
  # There should bde a more generic solution
  eltypes = map(eltype,values(ds.cubes))
  majtype = findmax(counter(eltypes))[2]
  newkeys = Symbol[]
  for k in keys(ds.cubes)
    c = ds.cubes[k]
    if all(axn->findAxis(axn,c)!==nothing,dls) && eltype(c)==majtype
      push!(newkeys,k)
    end
  end
  if length(newkeys)==1
    return ds.cubes[first(newkeys)]
  else
    varax = CategoricalAxis(joinname, string.(newkeys))
    return concatenateCubes([ds.cubes[k] for k in newkeys], varax)
  end
end



"""
    function createDataset(DS::Type{<:DatasetBackend},axlist; kwargs...)

Creates a new datacube with axes specified in `axlist`. Each axis must be a subtype
of `CubeAxis`. A new empty Zarr array will be created and can serve as a sink for
`mapCube` operations.

### Keyword arguments

* `folder=tempname()` location where the new cube is stored
* `T=Union{Float32,Missing}` data type of the target cube
* `chunksize = ntuple(i->length(axlist[i]),length(axlist))` chunk sizes of the array
* `chunkoffset = ntuple(i->0,length(axlist))` offsets of the chunks
* `compressor = NoCompressor()` compression type
* `persist::Bool=true` shall the disk data be garbage-collected when the cube goes out of scope?
* `overwrite::Bool=false` overwrite cube if it already exists
* `properties=Dict{String,Any}()` additional cube properties
* `fillvalue= T>:Missing ? defaultfillval(Base.nonmissingtype(T)) : nothing` fill value
* `datasetaxis="Variable"` special treatment of a categorical axis that gets written into separate zarr arrays
"""
function createDataset(DS, axlist;
  path=tempname(),
  T=Union{Float32,Missing},
  chunksize = ntuple(i->length(axlist[i]),length(axlist)),
  chunkoffset = ntuple(i->0,length(axlist)),
  persist::Bool=true,
  overwrite::Bool=false,
  properties=Dict{String,Any}(),
  datasetaxis = "Variable",
  kwargs...
  )
  if isdir(folder) || isfile(folder)
    if overwrite
      rm(folder,recursive=true)
    else
      error("$folder alrSeady exists, set overwrite=true to overwrite.")
    end
  end
  splice_generic(x::AbstractArray,i) = [x[1:(i-1)];x[(i+1:end)]]
  splice_generic(x::Tuple,i)         = (x[1:(i-1)]...,x[(i+1:end)]...)
  myar = create_empty(DS, path)
  if (iax = findAxis(datasetaxis,axlist)) !== nothing
    groupaxis = axlist[iax]
    axlist = splice_generic(axlist,iax)
    chunksize = splice_generic(chunksize,iax)
    chunkoffset = splice_generic(chunkoffset,iax)
  else
    groupaxis = nothing
  end
  foreach(axlist,chunkoffset) do ax,co
    arrayfromaxis(myar,ax,co)
  end
  attr = properties
  s = map(length,axlist) .+ chunkoffset
  if all(iszero,chunkoffset)
    subs = nothing
  else
    subs = ntuple(length(axlist)) do i
      (chunkoffset[i]+1):(length(axlist[i].values)+chunkoffset[i])
    end
  end
  if groupaxis===nothing
    cubenames = ["layer"]
  else
    cubenames = groupaxis.values
  end
  cleaner = persist ? nothing : CleanMe(folder,false)
  allcubes = map(cubenames) do cn
    add_var(myar, T, cn, map(length,axlist), map(axname,axlist), atts; chunksize = chunksize, kwargs...)
    if subs !== nothing
      za = view(za,subs...)
    end

    ESDLArray(axlist,za,propfromattr(attr),cleaner=cleaner)
  end
  if groupaxis===nothing
    return allcubes[1]
  else
    return concatenateCubes(allcubes,groupaxis)
  end
end

function arrayfromaxis(p::DatasetBackend,ax::CubeAxis,offs)
    data, attr = dataattfromaxis(ax,offs)
    attr["_ARRAY_OFFSET"]=offs
    za = add_var(p, eltype(data), axname(ax), size(data), (axname(ax),), attr)
    za[:] = data
    za
end



end
