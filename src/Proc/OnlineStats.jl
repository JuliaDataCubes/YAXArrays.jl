module DATOnlineStats
using OnlineStats
using Combinatorics
importall ..DAT
importall ..Cubes
importall ..Mask
import ...CABLABTools.totuple
export DATfitOnline


function DATfitOnline(xout,maskout,xin,maskin)
    for (mi,xi) in zip(maskin,xin)
        (mi & MISSING)==VALID && fit!(xout[1],xi)
    end
end


function DATfitOnline(xout,maskout,xin,maskin,splitmask1,cfun1)
  for (mi,xi) in zip(maskin,xin)
      (mi & MISSING)==VALID && fit!(xout[cfun1[splitmask1]],xi)
  end
end

function finalizeOnlineCube{T,N}(c::CubeMem{T,N})
    CubeMem{Float32,N}(c.axes,map(OnlineStats.value,c.data),c.mask)
end

function mapCube{T<:OnlineStat}(f::Type{T},cdata::AbstractCubeData;by=CubeAxis[],max_cache=1e7,kwargs...)
  inAxes=axes(cdata)
  inAxes2=filter(i->!in(typeof(i),by),inAxes)
  axcombs=combinations(inAxes2)
  totlengths=map(a->prod(map(length,a)),axcombs)*sizeof(Float32)
  smallenough=totlengths.<max_cache
  axcombs=collect(axcombs)[smallenough]
  totlengths=totlengths[smallenough]
  m,i=findmax(totlengths)
  ia=map(typeof,axcombs[i])
  outBroad=filter(ax->!in(typeof(ax),by) && !in(typeof(ax),ia),inAxes)
  mapCube(DATfitOnline,cdata,outtype=f,outBroadCastAxes=outBroad,indims=(totuple(ia),),finalizeOut=finalizeOnlineCube,genOut=i->f())
end

end
