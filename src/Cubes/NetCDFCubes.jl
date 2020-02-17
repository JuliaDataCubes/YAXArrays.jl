export NetCDFCube
import CFTime

function NetCDFCube(file,variable)
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
    vmapped = (x->x==mv ? missing : x).(v)
    ESDLArray(cubeaxes,variable, Dict{Any,Any}())
end
iscompressed(v::NetCDF.NcVar) = v.compress>0
getCubeDes(v::NetCDF.NcVar)="NetCDF data cube"
