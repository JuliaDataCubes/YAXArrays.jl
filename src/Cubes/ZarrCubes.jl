module ESDLZarr
import ...ESDL
import Distributed: myid
import Zarr: ZGroup, zopen, ZArray, NoCompressor, zgroup, zcreate, readblock!, S3Store, DirectoryStore
import ESDL.Cubes: cubechunks, iscompressed, AbstractCubeData, getCubeDes,
  caxes,chunkoffset, gethandle, subsetcube, axVal2Index, findAxis, _read, S3Cube,
  _write, cubeproperties, ConcatCube, concatenateCubes, _subsetcube, workdir, readcubedata, saveCube
import ESDL.Cubes.Axes: axname, CubeAxis, CategoricalAxis, RangeAxis, TimeAxis,
  axVal2Index_lb, axVal2Index_ub, get_step, getAxis
import Dates: Day,Hour,Minute,Second,Month,Year, Date, DateTime, TimeType
import IntervalSets: Interval, (..)
import CFTime: timedecode, timeencode
export (..), Cubes, getCubeData, CubeMask, cubeinfo
const spand = Dict("days"=>Day,"months"=>Month,"years"=>Year,"hours"=>Hour,"seconds"=>Second,"minutes"=>Minute)

mutable struct ZArrayCube{T,M,A<:ZArray{T},S} <: AbstractCubeData{T,M}
  a::A
  axes::Vector{CubeAxis}
  subset::S
  persist::Bool
  properties::Dict{String,Any}
end
getCubeDes(::ZArrayCube)="ZArray Cube"
caxes(z::ZArrayCube)=z.axes
iscompressed(z::ZArrayCube)=!isa(z.a.metadata.compressor,NoCompressor)
cubechunks(z::ZArrayCube)=z.a.metadata.chunks
cubeproperties(z::ZArrayCube) = z.properties
function chunkoffset(z::ZArrayCube)
  cc = cubechunks(z)
  map((s,c)->mod(first(s)-1,c),z.subset,cc)
end
chunkoffset(z::ZArrayCube{T,N,A,Nothing}) where A<:ZArray{T} where {T,N}  = ntuple(i->0,N)
Base.size(z::ZArrayCube) = map(length,onlyrangetuple(z.subset))
Base.size(z::ZArrayCube,i::Int) = length(onlyrangetuple(z.subset)[i])
@inline onlyrangetuple(x::Integer,r...) = onlyrangetuple(r...)
@inline onlyrangetuple(x,r...) = (x,onlyrangetuple(r...)...)
@inline onlyrangetuple(x::Integer) = ()
@inline onlyrangetuple() = ()
@inline onlyrangetuple(x) = (x,)
@inline onlyrangetuple(x::Tuple)=onlyrangetuple(x...)
Base.size(z::ZArrayCube{<:Any,<:Any,<:ZArray,Nothing}) = size(z.a)
Base.size(z::ZArrayCube{<:Any,<:Any,<:ZArray,Nothing},i::Int) = size(z.a,i)
#ESDL.Cubes.gethandle(z::ZArrayCube) = z.a


prependrange(r::AbstractRange,n) = n==0 ? r : range(first(r)-n*step(r),last(r),length=n+length(r))
function prependrange(r::AbstractArray,n)
  if n==0
    return r
  else
    step = r[2]-r[1]
    first = r[1] - step*n
    last = r[1] - step
    radd = range(first,last,length=n)
    return [radd;r]
  end
end

function dataattfromaxis(ax::CubeAxis{<:Number},n)
    prependrange(ax.values,n), Dict{String,Any}()
end
function dataattfromaxis(ax::CubeAxis{<:String},n)
    prependrange(1:length(ax.values),n), Dict{String,Any}("_ARRAYVALUES"=>collect(ax.values))
end
function dataattfromaxis(ax::CubeAxis{<:TimeType},n)
    refdate = Date(1980)
    data = timeencode(ax.values,"days since 1980-01-01")
    prependrange(data,n), Dict{String,Any}("units"=>"days since 1980-01-01")
end

function zarrayfromaxis(p::ZGroup,ax::CubeAxis,offs)
    data, attr = dataattfromaxis(ax,offs)
    attr["_ARRAY_DIMENSIONS"]=[axname(ax)]
    attr["_ARRAY_OFFSET"]=offs
    za = zcreate(eltype(data),p,axname(ax), length(data),attrs=attr)
    za[:] = data
    za
end


function cleanZArrayCube(y::ZArrayCube)
  if !y.persist && myid()==1
    rm(y.a.storage.folder,recursive=true)
  end
end

defaultfillval(T::Type{<:AbstractFloat}) = convert(T,1e32)
defaultfillval(::Type{Float16}) = Float16(3.2e4)
defaultfillval(T::Type{<:Integer}) = typemax(T)

"""
    function ZArrayCube(axlist; kwargs...)

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

"""
function ZArrayCube(axlist;
  folder=tempname(),
  T=Union{Float32,Missing},
  chunksize = ntuple(i->length(axlist[i]),length(axlist)),
  chunkoffset = ntuple(i->0,length(axlist)),
  compressor = NoCompressor(),
  persist::Bool=true,
  overwrite::Bool=false,
  properties=Dict{String,Any}(),
  fillvalue= T>:Missing ? defaultfillval(Base.nonmissingtype(T)) : nothing,
  )
  if isdir(folder)
    if overwrite
      rm(folder,recursive=true)
    else
      error("Folder $folder is not empty, set overwrite=true to overwrite.")
    end
  end
  myar = zgroup(folder)
  foreach(axlist,chunkoffset) do ax,co
    zarrayfromaxis(myar,ax,co)
  end
  attr = properties
  attr["_ARRAY_DIMENSIONS"]=reverse(map(axname,axlist))
  s = map(length,axlist) .+ chunkoffset
  if all(iszero,chunkoffset)
    subs = nothing
  else
    subs = ntuple(length(axlist)) do i
      (chunkoffset[i]+1):(length(axlist[i].values)+chunkoffset[i])
    end
  end
  za = zcreate(T, myar,"layer", s...,attrs=attr, fill_value=fillvalue,chunks=chunksize,compressor=compressor)
  zout = ZArrayCube{T,length(s),typeof(za),typeof(subs)}(za,axlist,subs,persist,propfromattr(attr))
  finalizer(cleanZArrayCube,zout)
  zout
end

function _read(z::ZArrayCube{<:Any,N,<:Any,<:Nothing},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  readblock!(thedata,z.a,r)
end

propfromattr(attr) = filter(i->i[1]!=="_ARRAY_DIMENSIONS",attr)

#Helper functions for subsetting indices
_getinds(s1,s,i) = s1[firstarg(i...)],Base.tail(i)
_getinds(s1::Int,s,i) = s1,i
function getsubinds(subset,inds)
    el,rest = _getinds(firstarg(subset...),subset,inds)
    (el,getsubinds(Base.tail(subset),rest)...)
end
getsubinds(subset::Tuple{},inds) = ()
firstarg(x,s...) = x

maybereshapedata(thedata::AbstractArray{<:Any,N},subinds::NTuple{N,<:Any}) where N = thedata
maybereshapedata(thedata,subinds) = reshape(thedata,map(length,subinds))


function _read(z::ZArrayCube{<:Any,N,<:Any},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  allinds = CartesianIndices(map(Base.OneTo,size(z.a)))
  subinds = map(getindex,allinds.indices,z.subset)
  r2 = getsubinds(subinds,r.indices)
  thedata = maybereshapedata(thedata,r2)
  readblock!(thedata,z.a,CartesianIndices(r2))
end

function _write(y::ZArrayCube{<:Any,N,<:Any,<:Nothing},thedata::AbstractArray,r::CartesianIndices{N}) where N
  readblock!(thedata,y.a,r,readmode=false)
end

function _write(z::ZArrayCube{<:Any,N,<:Any},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  allinds = CartesianIndices(map(Base.OneTo,size(z.a)))
  subinds = map(getindex,allinds.indices,z.subset)
  r2 = getsubinds(subinds,r.indices)
  thedata = maybereshapedata(thedata,subinds)
  readblock!(thedata,z.a,CartesianIndices(r2),readmode=false)
end

function toaxis(dimname,g,offs,len)
    axname = dimname in ("lon","lat","time") ? uppercasefirst(dimname) : dimname
    if !haskey(g,dimname)
      return RangeAxis(dimname, 1:len)
    end
    ar = g[dimname]
    if axname=="Time" && haskey(ar.attrs,"units")
        tsteps = timedecode(ar[:],ar.attrs["units"],get(ar.attrs,"calendar","standard"))
        TimeAxis(tsteps)
    elseif haskey(ar.attrs,"_ARRAYVALUES")
      vals = ar.attrs["_ARRAYVALUES"]
      CategoricalAxis(axname,vals)
    else
      axdata = testrange(ar[offs+1:end])
      RangeAxis(axname,axdata)
    end
end

"Test if data in x can be approximated by a step range"
function testrange(x)
  r = range(first(x),last(x),length=length(x))
  all(i->isapprox(i...),zip(x,r)) ? r : x
end
import DataStructures: counter

const static_vars = Set(["water_mask","country_mask","srex_mask"])
const country_numeric_labels = include("../CubeAPI/countrylabels.jl")
const country_numeric_alpha_2 = include("../CubeAPI/country_iso_numeric_iso_alpha2.jl")
const country_numeric_alpha_3 = include("../CubeAPI/country_iso_numeric_iso_alpha3.jl")
const countrylabels = country_numeric_labels
const srexlabels = include("../CubeAPI/srexlabels.jl")
const known_labels = Dict("water_mask"=>Dict(0x01=>"land",0x02=>"water"),"country_mask"=>countrylabels,"srex_mask"=>srexlabels)
const known_names = Dict("water_mask"=>"Water","country_mask"=>"Country","srex_mask"=>"SREXregion")

Cube(s::String;kwargs...) = Cube(zopen(s);kwargs...)
function Cube(;kwargs...)
  if haskey(ENV,"ESDL_CUBEDIR")
    Cube(ENV["ESDL_CUBEDIR"];kwargs...)
  elseif isdir("/home/jovyan/work/datacube/ESDCv2.0.0/esdc-8d-0.25deg-184x90x90-2.0.0.zarr/")
    Cube("/home/jovyan/work/datacube/ESDCv2.0.0/esdc-8d-0.25deg-184x90x90-2.0.0.zarr/";kwargs...)
  else
    S3Cube(;kwargs...)
  end
end
function CubeMask(s::String,v::String;kwargs...)
  vname =  string(v,"_mask")
  c = Cube(zopen(s);varlist=[vname],static=true,kwargs...)
  c.properties["labels"] = known_labels[vname]
  c.properties["name"]   = known_names[vname]
  readcubedata(c)
end
CubeMask(v;kwargs...) = CubeMask(get(ENV,"ESDL_CUBEDIR","/home/jovyan/work/datacube/ESDCv2.0.0/esdc-8d-0.25deg-184x90x90-2.0.0.zarr/"),v;static=true,kwargs...)


@deprecate getCubeData(c;longitude=(-180.0,180.0),latitude=(-90.0,90.0),kwargs...) subsetcube(c;lon=longitude,lat=latitude,kwargs...)

# function Cube(g::ZGroup;varlist=nothing,joinname="Variable",static=false)
#
#   if varlist===nothing
#     varlist = infervarlist(g)
#   end
#   v1 = g[varlist[1]]
#   s = size(v1)
#   vardims = reverse((v1.attrs["_ARRAY_DIMENSIONS"]...,))
#   offsets = map(i->get(g[i].attrs,"_ARRAY_OFFSET",0),vardims)
#   inneraxes = toaxis.(vardims,Ref(g),offsets)
#   iax = collect(CubeAxis,inneraxes)
#   s.-offsets == length.(inneraxes) || throw(DimensionMismatch("Array dimensions do not fit"))
#   allcubes = map(varlist) do iv
#     v = g[iv]
#     size(v) == s || throw(DimensionMismatch("All variables must have the same shape. $iv does not match $(varlist[1])"))
#     ZArrayCube{eltype(v),ndims(v),typeof(v),Nothing}(v,iax,nothing,true,propfromattr(v.attrs))
#   end
#   # Filter out minority element types
#   c = counter(eltype(i) for i in allcubes)
#   _,et = findmax(c)
#   indtake = findall(i->eltype(i)==et,allcubes)
#   allcubes = allcubes[indtake]
#   varlist  = varlist[indtake]
#   if length(allcubes)==1
#     cout =  allcubes[1]
#   else
#     cout = concatenateCubes(allcubes,CategoricalAxis(joinname,varlist))
#   end
#   if static
#     return subsetcube(cout,time=first(getAxis("Time",cout).values))
#   else
#     return cout
#   end
# end

sorted(x,y) = x<y ? (x,y) : (y,x)

interpretsubset(subexpr::Union{CartesianIndices{1},LinearIndices{1}},ax) = subexpr.indices[1]
interpretsubset(subexpr::CartesianIndex{1},ax)   = subexpr.I[1]
interpretsubset(subexpr,ax)                      = axVal2Index(ax,subexpr,fuzzy=true)
function interpretsubset(subexpr::NTuple{2,Any},ax)
  x, y = sorted(subexpr...)
  Colon()(sorted(axVal2Index_lb(ax,x),axVal2Index_ub(ax,y))...)
end
interpretsubset(subexpr::NTuple{2,Int},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(map(T,subexpr),ax)
interpretsubset(subexpr::UnitRange{Int64},ax::RangeAxis{T}) where T<:TimeType = interpretsubset(T(first(subexpr))..T(last(subexpr)+1),ax)
interpretsubset(subexpr::Interval,ax)       = interpretsubset((subexpr.left,subexpr.right),ax)
interpretsubset(subexpr::AbstractVector,ax::CategoricalAxis)      = axVal2Index.(Ref(ax),subexpr,fuzzy=true)

axcopy(ax::RangeAxis,vals) = RangeAxis(axname(ax),vals)
axcopy(ax::CategoricalAxis,vals) = CategoricalAxis(axname(ax),vals)

function _subsetcube(z::AbstractCubeData, subs;kwargs...)
  if :region in keys(kwargs)
    kwargs = collect(Any,kwargs)
    ireg = findfirst(i->i[1]==:region,kwargs)
    reg = splice!(kwargs,ireg)
    haskey(known_regions,reg[2]) || error("Region $(reg[2]) not known.")
    lon1,lat1,lon2,lat2 = known_regions[reg[2]]
    push!(kwargs,:lon=>lon1..lon2)
    push!(kwargs,:lat=>lat1..lat2)
  end
  newaxes = deepcopy(caxes(z))
  foreach(kwargs) do kw
    axdes,subexpr = kw
    axdes = string(axdes)
    iax = findAxis(axdes,caxes(z))
    if isa(iax,Nothing)
      throw(ArgumentError("Axis $axdes not found in cube"))
    else
      oldax = newaxes[iax]
      subinds = interpretsubset(subexpr,oldax)
      subs2 = subs[iax][subinds]
      subs[iax] = subs2
      if !isa(subinds,AbstractVector) && !isa(subinds,AbstractRange)
        newaxes[iax] = axcopy(oldax,oldax.values[subinds:subinds])
      else
        newaxes[iax] = axcopy(oldax,oldax.values[subinds])
      end
    end
  end
  substuple = ntuple(i->subs[i],length(subs))
  inewaxes = findall(i->isa(i,AbstractRange),substuple)
  newaxes = newaxes[inewaxes]
  @assert length.(newaxes) == map(length,(substuple |> onlyrangetuple)) |> collect
  newaxes, substuple
end

include(joinpath(@__DIR__,"../CubeAPI/countrydict.jl"))

function subsetcube(z::ZArrayCube{T};kwargs...) where T
  subs = isa(z.subset,Nothing) ? collect(Any,map(Base.OneTo,size(z))) : collect(Any,z.subset)
  newaxes, substuple = _subsetcube(z,subs;kwargs...)
  ZArrayCube{T,length(newaxes),typeof(z.a),typeof(substuple)}(z.a,newaxes,substuple,true,z.properties)
end

Base.getindex(a::AbstractCubeData;kwargs...) = subsetcube(a;kwargs...)

function subsetcube(z::ESDL.Cubes.ConcatCube{T,N};kwargs...) where {T,N}
  kwargs = collect(kwargs)
  isplitconcaxis = findfirst(kwargs) do kw
    axdes = string(kw[1])
    findAxis(axdes,caxes(z)) == N
  end
  if isa(isplitconcaxis,Nothing)
    #We only need to subset the inner cubes
    cubelist = map(i->subsetcube(i;kwargs...),z.cubelist)
    cubeaxes = caxes(first(cubelist))
    cataxis = deepcopy(z.cataxis)
  else
    subs = kwargs[isplitconcaxis][2]
    subinds = interpretsubset(subs,z.cataxis)
    cubelist = z.cubelist[subinds]
    isa(cubelist,AbstractCubeData) && (cubelist=[cubelist];subinds=[subinds])
    cataxis  = axcopy(z.cataxis,z.cataxis.values[subinds])
    kwargsrem = (kwargs[(1:isplitconcaxis-1)]...,kwargs[isplitconcaxis+1:end]...)
    if !isempty(kwargsrem)
      cubelist = [subsetcube(i;kwargsrem...) for i in cubelist]
    end
    cubeaxes = deepcopy(caxes(cubelist[1]))
  end
  return length(cubelist)==1 ? cubelist[1] : ConcatCube{T,length(cubeaxes)+1}(cubelist,cataxis,cubeaxes,cubeproperties(z))
end

function saveCube(z::ZArrayCube, name::AbstractString)
  newfolder = joinpath(workdir[1], name)
  isdir(newfolder) && error("$(name) already exists, please pick another name")
  # the julia cp implentation currently can only deal with files <2GB
  # the issue is:
  # https://github.com/JuliaLang/julia/issues/14574
  # mv(c.folder,newfolder)
  if z.a.storage isa DirectoryStore
    folder = splitdir(z.a.storage.folder)
    run(`mv $(folder[1]) $(newfolder)`)
    z.a = zopen(newfolder * "/layer")
  elseif z.a.storage isa S3Store
    error("Saving a cube based on a $(z.a.storage) not implemented yet")
  else
    error("Unknown store-type")
  end
end

"""
    loadCube(name::String)
Loads a cube that was previously saved with [`saveCube`](@ref). Returns a
`TempCube` object.
"""
function loadCube(name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) || error("$(name) does not exist")
  Cube(newfolder)
end

"""
    rmCube(name::String)

Deletes a memory-mapped data cube.
"""
function rmCube(name::String)
  newfolder=joinpath(workdir[1],name)
  isdir(newfolder) && rm(newfolder,recursive=true)
  nothing
end
export rmCube, loadCube


using Markdown
struct ESDLVarInfo
  project::String
  longname::String
  units::String
  url::String
  comment::String
  reference::String
end
Base.isless(a::ESDLVarInfo, b::ESDLVarInfo) = isless(string(a.project, a.longname),string(b.project, b.longname))

import Base.show
function show(io::IO,::MIME"text/markdown",v::ESDLVarInfo)
    un=v.units
    url=v.url
    re=v.reference
    pr = v.project
    ln = v.longname
    co = v.comment
    mdt=md"""
### $ln
*$(co)*

* **Project** $(pr)
* **units** $(un)
* **Link** $(url)
* **Reference** $(re)
"""
    mdt[3].items[1][1].content[3]=[" $pr"]
    mdt[3].items[2][1].content[3]=[" $un"]
    mdt[3].items[3][1].content[3]=[" $url"]
    mdt[3].items[4][1].content[3]=[" $re"]
    show(io,MIME"text/markdown"(),mdt)
end
show(io::IO,::MIME"text/markdown",v::Vector{ESDLVarInfo})=foreach(x->show(io,MIME"text/markdown"(),x),v)
import Zarr: zname

"""
    cubeinfo(cube)

Shows the metadata and citation information on variables contained in a cube.
"""
function cubeinfo(cube::ZArrayCube)
    p = cube.properties
    variable = zname(cube.a)
    vi=ESDLVarInfo(
      get(p,"project_name", "unknown"),
      get(p,"long_name",variable),
      get(p,"units","unknown"),
      get(p,"url","no link"),
      get(p,"comment",variable),
      get(p,"references","no reference")
    )
end
function cubeinfo(cube::ConcatCube)
  allinfos = sort([cubeinfo(c) for c in cube.cubelist])
end


end # module
