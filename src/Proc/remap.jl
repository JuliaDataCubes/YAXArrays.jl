using DiskArrayTools: InterpolatedDiskArray
using Interpolations: Linear, Flat, Constant, NoInterp
using DiskArrays: eachchunk, GridChunks
"""
  spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
"""
function spatialinterp(c::AbstractCubeData,newlons::AbstractRange,newlats::AbstractRange;order=Linear(),bc = Flat())
  interpolatecube(c,Dict("Lon"=>newlons, "Lat"=>newlats), order = Dict("Lon"=>Linear(),"Lat"=>Linear()))
end
spatialinterp(c::AbstractCubeData,newlons::CubeAxis,newlats::CubeAxis;kwargs...)=
  spatialinterp(c,newlons.values,newlats.values;kwargs...)

  function expandchunksizes(c,newaxdict)
    k = collect(keys(newaxdict))
    chunkold = eachchunk(c.data)
    axold = caxes(c)
    axinds  = map(i->findAxis(i,c),k)
    axsteps = map(i->step(axold[i].values),axinds)
    steprats = map((i,s)->step(newaxdict[i])/s,k,axsteps)
    newcs = ntuple(ndims(c)) do i
          ii = findfirst(isequal(i),axinds)
          round(Int,chunkold.chunksize[i] * (ii==nothing ? 1 : steprats[ii]))
      end
      newco = ntuple(ndims(c)) do i
          ii = findfirst(isequal(i),axinds)
          round(Int,chunkold.offset[i] * (ii==nothing ? 1 : steprats[ii]))
      end
    newchunks = GridChunks(size(c),newcs, offset = newco)
  end

function interpolatecube(c::AbstractCubeData,
  newaxes::Dict,
  newchunks = expandchunksizes(c,newaxes);
  order=Dict()
  )
  ii = map(axn->(axn,findAxis(axn,c)),collect(keys(newaxes)))
  oo = ntuple(ndims(c)) do i
    ai = findfirst(j->j[2]==i,ii)
    if ai === nothing
      nothing,NoInterp(),nothing
    else
      oldvals = caxes(c)[i].values
      newvals = newaxes[ii[ai][1]]
      getinterpinds(oldvals, newvals),get(order,ai[1],Constant()),newvals
    end
  end
  newinds = getindex.(oo,1)
  intorder = getindex.(oo,2)
  ar = InterpolatedDiskArray(c.data,newchunks,newinds..., order = intorder)
  newvals = getindex.(oo,3)
  newax = map(caxes(c),newvals) do ax,val
    if val === nothing
      ax
    else
      RangeAxis(axname(ax),val)
    end
  end
  ESDLArray(newax,ar,c.properties, cleaner = c.cleaner)
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
