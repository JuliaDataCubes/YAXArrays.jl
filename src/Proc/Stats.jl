module Stats
export normalize, timeVariance, timeMean, spatialMean
importall ..DAT
importall ..CubeAPI
importall ..Proc
importall ..Cubes

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
  @no_ocean maskin maskout
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
  xout[1]=v
end

function timeMean{T}(xout::AbstractArray{T,0},maskout::AbstractArray{UInt8,0},xin::AbstractVector{T},maskin::AbstractVector)
  @no_ocean maskin maskout
  s=zero(T)
  n=0
  for i in eachindex(xin)
    if maskin[i]==VALID
      s+=xin[i]
      n+=1
    end
  end
  if n>0
    xout[1]=s/n
    maskout[1]=VALID
  else
    xout[1]=NaN
    maskout[1]=MISSING
  end

end

function spatialMean{T}(xout::AbstractArray{T,0},maskout::AbstractArray{UInt8,0},xin::AbstractMatrix,maskin::AbstractMatrix{UInt8},lat,latmask)
  s=zero(xin[1])
  sw=zero(cosd(lat[1]))
  for ilat=1:size(xin,2)
    w    = cosd(lat[ilat])
    for ilon = 1:size(xin,1)
      if maskin[ilon,ilat]==VALID
        s+=xin[ilon,ilat]
        sw+=w
      end
    end
  end
  xout[1]=s/sw
end

registerDATFunction(spatialMean,((LonAxis,LatAxis),(LatAxis,)),())
registerDATFunction(normalize,(TimeAxis,),(TimeAxis,))
registerDATFunction(timeMean,(TimeAxis,),())
registerDATFunction(timeVariance,(TimeAxis,),())



end
