export NetCDFCube
import CFTime
mutable struct NetCDFCube{T,N,S} <: AbstractCubeData{T,N}
  file::String
  varname::String
  axes::Vector{CubeAxis}
  mv::T
  subset::S
  properties
end

function NetCDFCube(file,variable)
  NetCDF.open(file) do nc
    v = nc.vars[variable]
    #Find lon,lat,time dimensions if they exist
    cubeaxes = CubeAxis[]
    for dim in v.dim
    dimname=dim.name
    if startswith(uppercase(dimname),"LON")
      haskey(nc.vars,dimname) || error("Longitude variable does not exist")
      push!(cubeaxes,LonAxis(range(nc.vars[dimname][1], stop=nc.vars[dimname][end], length=dim.dimlen)))
    elseif startswith(uppercase(dimname),"LAT")
      haskey(nc.vars,dimname) || error("Latitude variable does not exist")
      push!(cubeaxes,LatAxis(range(nc.vars[dimname][1], stop=nc.vars[dimname][end], length=dim.dimlen)))
    elseif startswith(uppercase(dimname),"TIME")
      haskey(nc.vars,dimname) || error("Time variable does not exist")
      timvals = nc.vars[dimname][:]
      if haskey(nc.vars[dimname].atts,"units")
        cal = get(nc.vars[dimname].atts,"calendar","standard")
        push!(cubeaxes,TimeAxis(CFTime.timedecode(timvals,nc.vars[dimname].atts["units"],cal, prefer_datetime = true)))
      else
        push!(cubeaxes,RangeAxis(dimname,timvals))
      end
      haskey(nc.vars,dimname) || error("Longitude variable does not exist")
    else
      push!(cubeaxes,CategoricalAxis(dimname,haskey(nc.vars,dimname) ? nc.vars[dimname][:] : collect(1:dim.dimlen)))
    end
    end
    mv = get(v.atts,"missing_value",nothing)
    et = mv === nothing ? eltype(v) : Union{Missing,eltype(v)}
    NetCDFCube{et,length(cubeaxes),Nothing}(file,variable,cubeaxes,mv,nothing,Dict{Any,Any}())
  end
end
function subsetcube(z::NetCDFCube{T};kwargs...) where T
  subs = isa(z.subset,Nothing) ? collect(Any,map(Base.OneTo,size(z))) : collect(Any,z.subset)
  newaxes, substuple = _subsetcube(z,subs;kwargs...)
  NetCDFCube{T,length(newaxes),typeof(substuple)}(z.file,z.varname,newaxes,z.mv,substuple,z.properties)
end
Base.size(x::NetCDFCube)=ntuple(i->length(x.axes[i]),length(x.axes))
Base.size(x::NetCDFCube,i)=length(x.axes[i])
function iscompressed(x::NetCDFCube)
  NetCDF.open(x.file, x.varname) do v
    v.compress>0
  end
end
caxes(v::NetCDFCube)=deepcopy(v.axes)
getCubeDes(v::NetCDFCube)="NetCDF data cube"
function _read(x::NetCDFCube{T,N},thedata::AbstractArray,r::CartesianIndices{N}) where {T,N}
  allinds = NetCDF.open(x.file,x.varname) do v
    (map(i->Base.OneTo(i.dimlen),v.dim)...,)
  end |> CartesianIndices
  subinds = map(getindex,allinds.indices,getsubset(x))
  r2 = getsubinds(subinds,r.indices)
  sta = map(first,r2) |> collect
  cou = map(length,r2) |> collect
  d = ncread(x.file,x.varname,start = sta,count=cou)
  map!(i->isequal(i,x.mv) ? missing : i, thedata,d)
end
