module Datasets
import ..Cubes.ESDLZarr: toaxis, axname, AbstractCubeData, ZArrayCube, propfromattr, subsetcube, caxes, concatenateCubes
import Zarr: ZGroup, zopen
import ..Cubes.Axes: axsym, CubeAxis, findAxis, CategoricalAxis
import ..Cubes: AbstractCubeData, Cube
import DataStructures: OrderedDict, counter
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
    ids = map(name->fuzzyfind(name,istr),i)
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
function collectdims(g::ZGroup)
  dlist = Set{Tuple{String,Int,Int}}()
  foreach(g.arrays) do ar
    k,v = ar
    for (len,dname) in zip(size(v),reverse(v.attrs["_ARRAY_DIMENSIONS"]))
      if !occursin("bnd",dname) && !occursin("bounds",dname) 
        offs = get(g.arrays[dname].attrs,"_ARRAY_OFFSET",0)
        push!(dlist,(dname,offs,len))
      end
    end
  end
  outd = Dict(d[1] => (ax = toaxis(d[1],g,d[2],d[3]), offs = d[2]) for d in dlist)
  length(outd)==length(dlist) || throw(ArgumentError("All Arrays must have the same offset"))
  outd
end

function Dataset(g::ZGroup)

  isempty(g.arrays) && throw(ArgumentError("Zarr Group does not contain datasets."))
  dimlist = collectdims(g)
  dnames  = string.(keys(dimlist))
  varlist = filter(g.arrays) do ar
    upname = uppercase(ar[1])
    !occursin("BNDS",upname) && !occursin("BOUNDS",upname) && !any(i->isequal(upname,uppercase(i)),dnames)
  end
  allcubes = OrderedDict{Symbol,AbstractCubeData}()
  for iv in  varlist
    vname, zarray = iv
    vardims = reverse((zarray.attrs["_ARRAY_DIMENSIONS"]...,))
    iax = [dimlist[vd].ax for vd in vardims]
    offs = [dimlist[vd].offs for vd in vardims]
    subs = if all(iszero,offs)
      nothing
    else
      ntuple(i->(offs[i]+1):(offs[i]+length(iax[i])),length(offs))
    end
    allcubes[Symbol(vname)] = ZArrayCube{eltype(zarray),ndims(zarray),typeof(zarray),typeof(subs)}(zarray,iax,subs,true,propfromattr(zarray.attrs))
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

Cube(z::ZGroup;joinname="Variable") = Cube(Dataset(z),joinname=joinname)



end
