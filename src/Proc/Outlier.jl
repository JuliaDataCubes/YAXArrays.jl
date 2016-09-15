module Outlier
export recurrences, DAT_detectAnomalies!
importall ..DAT
importall ..CubeAPI
importall ..Cubes
import ..Proc
using Distances
using MultivariateAnomalies

function recurrences(recurrence_num::AbstractVector,D::AbstractArray, rec_threshold::Float64, temp_excl::Int = 5)
  N = size(D, 1)
  @assert N==length(recurrence_num)
  @inbounds for i = 1:N
  for j = 1:max(i-temp_excl-1,1)
    if D[i, j] < rec_threshold
      recurrence_num[i] = recurrence_num[i] + 1
    end
  end
  for j = min(i+temp_excl+1,N):N
    if D[i, j] < rec_threshold
      recurrence_num[i] = recurrence_num[i] + 1
    end
  end
end
return(recurrence_num)
end


function recurrences(xout::AbstractVector,maskout::AbstractVector,xin::AbstractMatrix,maskin::AbstractMatrix,rec_threshold::Float64, temp_excl::Int,distmatspace::AbstractMatrix)
  pairwise!(distmatspace,Euclidean(),xin)
  fill!(xout,zero(eltype(xout)))
  recurrences(xout,distmatspace,rec_threshold,temp_excl)
  fill!(maskout,zero(UInt8))
  for itime=1:size(maskin,2), ivar=1:size(maskin,1)
    maskout[itime]=maskout[itime] | maskin[ivar,itime]
  end
  xout
end

registerDATFunction(recurrences,(VariableAxis,TimeAxis),(TimeAxis,),(cube,pargs)->begin
    ax=axes(cube[1])
    isTime=[isa(a,TimeAxis) for a in ax]
    ntime=length(ax[isTime[1]])
    (pargs[1],pargs[2],zeros(eltype(cube[1]),ntime,ntime))
  end)


function getDetectParameters(methodlist,trainarray,ntime)
  P = getParameters(methodlist,trainarray);
  init_detectAnomalies(zeros(Float64,ntime,size(trainarray,2)), P);
  (P,)
end
function DAT_detectAnomalies!(xout::AbstractArray, xin::AbstractArray, P::MultivariateAnomalies.PARAMS)
 detectAnomalies!(xin, P)
 for i = 1:length(P.algorithms)
   copy!(sub(xout, :, i), MultivariateAnomalies.return_scores(i, P))
 end
 return(xout)
end
registerDATFunction(DAT_detectAnomalies!,(TimeAxis,VariableAxis),(TimeAxis,(cube,pargs)->MethodAxis(pargs[1])),
(cube,pargs)->getDetectParameters(pargs[1],pargs[2],length(Proc.Stats.getAxis(cube[1],TimeAxis))),inmissing=(:nan,),outmissing=:nan,no_ocean=1)


end
