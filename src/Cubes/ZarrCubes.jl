module ESDLZarr
import ...ESDL
import ZarrNative: ZGroup, zopen, ZArray, NoCompressor, zgroup, zcreate
import ESDL.Cubes: cubechunks, iscompressed, AbstractCubeData, getCubeDes,
  caxes,chunkoffset, gethandle, subsetcube, axVal2Index, findAxis, _read,
  _write, cubeproperties, ConcatCube
import ESDL.Cubes.Axes: axname, CubeAxis, CategoricalAxis, RangeAxis
import Dates: Day,Hour,Minute,Second,Month,Year, Date
import IntervalSets: Interval, (..)
export (..)
const spand = Dict("days"=>Day,"months"=>Month,"years"=>Year,"seconds"=>Second,"minutes"=>Minute)

mutable struct ZArrayCube{T,N,A<:ZArray{T,N},S} <: AbstractCubeData{T,N}
  a::A
  axes::Vector{CubeAxis}
  subset::S
end
import ZarrNative: readblock!
getCubeDes(::ZArrayCube)="ZArray Cube"
caxes(z::ZArrayCube)=z.axes
iscompressed(z::ZArrayCube)=!isa(z.a.metadata.compressor,ZarrNative.NoCompressor)
cubechunks(z::ZArrayCube)=z.a.metadata.chunks
function chunkoffset(z::ZArrayCube)
  cc = cubechunks(z)
  map((s,c)->mod(s-1,c),s.subset,cc)
end
Base.size(z::ZArrayCube) = map(length,z.subset)
Base.size(z::ZArrayCube{<:Any,<:Any,<:ZArray,Nothing}) = size(z.a)
#ESDL.Cubes.gethandle(z::ZArrayCube) = z.a

function dataattfromaxis(ax::CubeAxis{<:Number})
    ax.values, Dict{String,Any}()
end
function dataattfromaxis(ax::CubeAxis{<:String})
    1:length(ax.values), Dict{String,Any}("_ARRAYVALUES"=>collect(ax.values))
end
function dataattfromaxis(ax::CubeAxis{<:Date})
    refdate = Date(1980)
    vals = map(i->(i-refdate)/oneunit(Day),ax.values)
    vals, Dict{String,Any}("units"=>"days since 1980-01-01")
end

function zarrayfromaxis(p::ZGroup,ax::CubeAxis,offs)
    data, attr = dataattfromaxis(ax)
    attr["_ARRAY_DIMENSIONS"]=[axname(ax)]
    attr["_ARRAY_OFFSET"]=offs
    za = zcreate(p,axname(ax), eltype(data),length(data),attrs=attr)
    za[:] = data
    za
end


function cleanZArrayCube(y::ZArrayCube)
  if !y.persist && myid()==1
    rm(y.a.storage.folder,recursive=true)
  end
end

function ZArrayCube(axlist;
  folder=tempname(),
  T=Float32,
  chunksize = map(length,axlist),
  chunkoffset = ntuple(i->0,length(axlist)),
  compressor = NoCompressor(),
  persist::Bool=true,
  overwrite::Bool=false,
  properties=Dict{String,Any}(),
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
  attr = Dict("_ARRAY_DIMENSIONS"=>reverse(map(axname,axlist)))
  s = map(length,axlist) .+ chunkoffset
  if all(iszero,chunkoffset)
    subs = nothing
  else
    subs = ntuple(length(axlist)) do i
      (chunkoffset[i]+1):(length(axlist.values[i])+chunkoffset[i])
    end
  end
  za = zcreate(myar,"layer", T , s...,attrs=attr)
  zout = ZArrayCube(za,axlist,subs)
  finalizer(cleanZArrayCube,zout)
  zout
end

function _read(z::ZArrayCube{<:Any,N,<:Any,<:Nothing},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  readblock!(thedata,z.a,r)
end



#Helper functions for subsetting indices
_getinds(s1,s,i) = s1[firstarg(i...)],Base.tail(i)
_getinds(s1::Int,s,i) = s1,i
function getsubinds(subset,inds)
    el,rest = _getinds(firstarg(subset...),subset,inds)
    (el,getsubinds(Base.tail(subset),rest)...)
end
getsubinds(subset::Tuple{},inds) = ()
firstarg(x,s...) = x


function _read(z::ZArrayCube{<:Any,N,<:Any},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  allinds = CartesianIndices(map(Base.OneTo,size(z.a)))
  subinds = map(getindex,allinds.indices,z.subset)
  r2 = getsubinds(subinds,r.indices)
  readblock!(thedata,z.a,CartesianIndices(r2))
end

function _write(y::ZArrayCube{<:Any,N,<:Any,<:Nothing},thedata::AbstractArray,r::CartesianIndices{N}) where N
  readblock!(thedata,z.a,r,readmode=false)
end

function _write(z::ZArrayCube{<:Any,N,<:Any},thedata::AbstractArray{<:Any,N},r::CartesianIndices{N}) where N
  allinds = CartesianIndices(map(Base.OneTo,size(z.a)))
  subinds = map(getindex,allinds.indices,z.subset)
  r2 = getsubinds(subinds,r.indices)
  readblock!(thedata,z.a,CartesianIndices(r2),readmode=false)
end

function infervarlist(g::ZGroup)
  any(isequal("layer"),keys(g.arrays)) && return ["layer"]
  dimsdict = Dict{Tuple,Vector{String}}()
  foreach(g.arrays) do ar
    k,v = ar
    vardims = reverse((v.attrs["_ARRAY_DIMENSIONS"]...,))
    haskey(dimsdict,vardims) ? push!(dimsdict[vardims],k) : dimsdict[vardims] = [k]
  end
  filter!(p->!in("bnds",p[1]),dimsdict)
  llist = Dict(p[1]=>length(p[2]) for p in dimsdict)
  _,dims = findmax(llist)
  varlist = dimsdict[dims]
end

function parsetimeunits(unitstr)
    re = r"(\w+) since (\d\d\d\d)-(\d\d)-(\d\d)"

    m = match(re,unitstr)

    refdate = Date(map(i->parse(Int,m[i]),2:4)...)
    refdate,spand[m[1]]
end
function toaxis(dimname,g)
    axname = dimname in ("lon","lat","time") ? uppercasefirst(dimname) : dimname
    ar = g[dimname]
    if axname=="Time" && haskey(ar.attrs,"units")
        refdate,span = parsetimeunits(ar.attrs["units"])
        tsteps = refdate.+span.(ar[:])
        TimeAxis(tsteps)
    elseif haskey(ar.attrs,"_ARRAYVALUES")
      vals = ar.attrs["_ARRAYVALUES"]
      CategoricalAxis(axname,vals)
    else
      axdata = testrange(ar[:])
      RangeAxis(axname,axdata)
    end
end

"Test if data in x can be approximated by a step range"
function testrange(x)
  r = range(first(x),last(x),length=length(x))
  all(i->isapprox(i...),zip(x,r)) ? r : x
end
import DataStructures: counter

function Cube(g::ZGroup;varlist=nothing,joinname="Variable")

  if varlist===nothing
    varlist = infervarlist(g)
  end
  v1 = g[varlist[1]]
  s = size(v1)
  vardims = reverse((v1.attrs["_ARRAY_DIMENSIONS"]...,))
  inneraxes = toaxis.(vardims,Ref(g))
  offsets = map(i->g[i].attrs["_ARRAY_OFFSET"],vardims)
  iax = collect(CubeAxis,inneraxes)
  s.-offsets == length.(inneraxes) || throw(DimensionMismatch("Array dimensions do not fit"))
  allcubes = map(varlist) do iv
    v = g[iv]
    size(v) == s || throw(DimensionMismatch("All variables must have the same shape. $iv does not match $(varlist[1])"))
    ZArrayCube(v,iax,nothing)
  end
  # Filter out minority element types
  c = counter(eltype(i) for i in allcubes)
  _,et = findmax(c)
  indtake = findall(i->eltype(i)==et,allcubes)
  allcubes = allcubes[indtake]
  varlist  = varlist[indtake]
  if length(allcubes)==1
    return allcubes[1]
  else
    return concatenateCubes(allcubes,CategoricalAxis(joinname,varlist))
  end
end

sorted(x,y) = x<y ? (x,y) : (y,x)

interpretsubset(subexpr::Union{CartesianIndices{1},LinearIndices{1}},ax) = subexpr.indices[1]
interpretsubset(subexpr::CartesianIndex{1},ax)   = subexpr.I[1]
interpretsubset(subexpr,ax)                      = axVal2Index(ax,subexpr,fuzzy=true)
interpretsubset(subexpr::NTuple{2,Any},ax)       = Colon()(sorted(axVal2Index(ax,subexpr[1]),axVal2Index(ax,subexpr[2]))...)
interpretsubset(subexpr::Interval,ax)       = Colon()(sorted(axVal2Index(ax,subexpr.left),axVal2Index(ax,subexpr.right))...)
interpretsubset(subexpr::AbstractVector,ax::CategoricalAxis)      = axVal2Index.(Ref(ax),subexpr,fuzzy=true)

axcopy(ax::RangeAxis,vals) = RangeAxis(axname(ax),vals)
axcopy(ax::CategoricalAxis,vals) = CategoricalAxis(axname(ax),vals)

function subsetcube(z::ZArrayCube;kwargs...)
  subs = isnothing(z.subset) ? collect(Any,map(Base.OneTo,size(z))) : collect(z.subset)
  newaxes = deepcopy(caxes(z))
  foreach(kwargs) do kw
    axdes,subexpr = kw
    axdes = string(axdes)
    iax = findAxis(axdes,caxes(z))
    if isnothing(iax)
      throw(ArgumentError("Axis $axdes not found in cube"))
    else
      oldax = newaxes[iax]
      subinds = interpretsubset(subexpr,oldax)
      subs2 = subs[iax][subinds]
      subs[iax] = subs2
      newaxes[iax] = axcopy(oldax,oldax.values[subinds])
    end
  end
  newaxes = filter(ax->length(ax)>1,newaxes) |> collect
  ZArrayCube(z.a,newaxes,ntuple(i->subs[i],length(subs)))
end

function subsetcube(z::ESDL.Cubes.ConcatCube{T,N};kwargs...) where {T,N}
  kwargs = collect(kwargs)
  isplitconcaxis = findfirst(kwargs) do kw
    axdes = string(kw[1])
    findAxis(axdes,caxes(z)) == N
  end
  if isnothing(isplitconcaxis)
    #We only need to subset the inner cubes
    cubelist = map(i->subsetcube(i;kwargs...),z.cubelist)
    cubeaxes = caxes(first(z.cubelist))
    cataxis = deepcopy(z.cataxis)
  else
    subs = kwargs[isplitconcaxis][2]
    subinds = interpretsubset(subs,z.cataxis)
    cubelist = z.cubelist[subinds]
    !isa(cubelist,AbstractVector) && (cubelist=[cubelist])
    cataxis  = axcopy(z.cataxis,z.cataxis.values[subinds])
    kwargsrem = (kwargs[(1:isplitconcaxis-1)]...,kwargs[isplitconcaxis+1:end]...)
    if !isempty(kwargsrem)
      cubelist = CubeAxis[subsetcube(i;kwargsrem...) for i in z.cubelist]
    end
    cubeaxes = deepcopy(caxes(cubelist[1]))
  end
  return length(cubelist)==1 ? cubelist[1] : ConcatCube{T,N}(cubelist,cataxis,cubeaxes,cubeproperties(z))
end

end # module
