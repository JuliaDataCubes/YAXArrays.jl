module Proc
export removeMSC!, gapFillMSC, recurrences!, normalize
using ..DAT, ..CubeAPI

include("MSC.jl")
include("Outlier.jl")

importall .MSC, .Outlier

function normalize{T}(xin::AbstractVector{T},xout::AbstractVector,maskin::AbstractVector,maskout::AbstractVector)
  s=zero(T)
  s2=zero(T)*zero(T)
  n=0
  for i in eachindex(xin)
    if maskin[i]==VALID
      s+=xin[i]
      s2+=xin[i]*xin[i]
      n+=1
    end
  end
  m=s/n
  v=s2/n-m*m
  for i in eachindex(xout)
    xout[i]=(xin[i]-m)/sqrt(v)
  end
  copy!(maskout,maskin)
end
@registerDATFunction normalize (TimeAxis,) (TimeAxis,)

end
