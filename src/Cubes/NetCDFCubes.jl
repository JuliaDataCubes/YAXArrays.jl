export NetCDFCube
mutable struct NetCDFCube{T,N} <: AbstractCubeData{T,N}
  file::String
  varname::String
  axes::Vector{CubeAxis}
  mv::T
  properties
end

function NetCDFCube(file,variable,timesteps;mv=nothing)
nc = NetCDF.open(file)
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
    #haskey(nc.vars,dimname) || error("Time variable does not exist")
    #instead of parsing the time steps we use the user input for now
    push!(cubeaxes,TimeAxis(timesteps))
  else
    push!(cubeaxes,CategoricalAxis(dimname,haskey(nc.vars,dimname) ? nc.vars[dimname][:] : collect(1:dim.dimlen)))
  end
end
  if mv==nothing
    mv = get(v.atts,"missing_value",typemax(eltype(v)))
  end
  NetCDFCube{eltype(v),length(cubeaxes)}(file,variable,cubeaxes,mv,Dict{Any,Any}())
end
Base.size(x::NetCDFCube)=ntuple(i->length(x.axes[i]),length(x.axes))
Base.size(x::NetCDFCube,i)=length(x.axes[i])
caxes(v::NetCDFCube)=deepcopy(v.axes)
getCubeDes(v::NetCDFCube)="NetCDF data cube"
function _read(x::NetCDFCube{T,N},thedata::Tuple{Any,Any},r::CartesianIndices{N}) where {T,N}
  sta = collect(r.start.I)
  cou = [r.stop.I[i]-r.start.I[i]+1 for i=1:N]
  ncread!(x.file,x.varname,thedata[1],start = sta,count=cou)
  map!(i->i==x.mv ? 0x01 : 0x00, thedata[2],thedata[1])
end
