module Outlier
export recurrences
importall ..DAT
importall ..CubeAPI
using Distances

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

@registerDATFunction recurrences (VariableAxis,TimeAxis) (TimeAxis,) rec_threshold::Float64 temp_excl::Int distmatspace::AbstractMatrix

end
