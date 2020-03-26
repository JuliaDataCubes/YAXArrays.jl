using DiskArrayTools: InterpolatedDiskArray

"""
  spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
"""
function spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
  interpolatecube(c,Dict("Lon"=>newlons, "Lat"=>newlats), order = Dict("Lon"=>Linear(),"Lat"=>Linear()))
end
spatialinterp(c::AbstractCubeData,newlons::CubeAxis,newlats::CubeAxis;kwargs...)=
  spatialinterp(c,newlons.values,newlats.values;kwargs...)

function interpolatecube(c::AbstractCubeData,newaxes::Dict,newchunks::Dict;order=Dict())
  ii = map(axn->(axn,findAxis(axn,c)),keys(newaxes))
  oo = ntuple(ndims(c)) do i
    ai = findfirst(j->j[2]==i,ii)
    if a === nothing
      nothing,NoInterp()
    else
      oldvals = caxes(c)[i].values
      newvals = newaxes[ii[ai][1]].values
      getinterpinds(oldvals, newvals),get(order,a[1],Constant())
    end
  end
  newinds = getindex.(oo,1)
  intorder = getindex.(oo,2)
  ar = InterpolatedDiskArray(ad,newchunks,newinds, order = intorder)
  newax = map(caxes(c),newinds) do ax,val
    if val === nothing
      ax
    else
      RangeAxis(axname(ax),val)
    end
  end
  ESDLArray(newax,ar, properties = c.properties, cleaner = c.cleaner)
end

function getinterpinds(oldvals::AbstractRange, newvals::AbstractRange)
  (newvals.-first(oldvals))./step(oldvals).+1
end
function getinterpinds(r1,r2)
  rev = issorted(r1) ? false : issorted(r1,rev=true) ? true : error("Axis values are not sorted")
  map(r2) do ir
    ii = searchsortedfirst(r1,ir,rev=rev)
    ii1 = max(min(ii-1,length(r1)),1)
    ii2 = max(min(ii,length(r1)),1)
    ind = if ii1 == ii2
      Float64(ii1)
    else
      ii1+(ir-r1[ii1])/(r1[ii2]-r1[ii1])
    end
    ind
  end
end
