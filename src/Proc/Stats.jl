module Stats
export normalize, timeVariance, timeMean, spatialMean
importall ..DAT
importall ..CubeAPI

function normalize{T}(xout::AbstractVector,maskout::AbstractVector,xin::AbstractVector{T},maskin::AbstractVector)
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

function timeVariance{T}(xout::AbstractArray{T,0},maskout::AbstractArray{UInt8,0},xin::AbstractVector{T},maskin::AbstractVector)
  s=zero(T)
  s2=zero(T)*zero(T)
  n=0
  for i in eachindex(xin)
    if maskin[i]==CABLAB.VALID
      s+=xin[i]
      s2+=xin[i]*xin[i]
      n+=1
    end
  end
  m=s/n
  v=s2/n-m*m
  xout[1]=v
end

function timeMean{T}(xout::AbstractArray{T,0},maskout::AbstractArray{UInt8,0},xin::AbstractVector{T},maskin::AbstractVector)
  s=zero(T)
  n=0
  for i in eachindex(xin)
    if maskin[i]==CABLAB.VALID
      s+=xin[i]
      n+=1
    end
  end
  xout[1]=v
end

#TODO reimplement as soon as spatial weights are clarified
function spatialMean{T}(xout::AbstractArray{T,0},maskout::AbstractArray{UInt8,0},xin::AbstractMatrix,maskin::AbstractArray{UInt8,2})
  s=zero(T)
  n=0
  for i in eachindex(xin)
    if maskin[i]==VALID
      s+=xin[i]
      n+=1
    end
  end
  m=s/n
  xout[1]=m
end

@registerDATFunction spatialMean (LonAxis,LatAxis) ()
@registerDATFunction normalize (TimeAxis,) (TimeAxis,)
@registerDATFunction timeMean (TimeAxis,) ()
@registerDATFunction timeVariance (TimeAxis,) ()



end
