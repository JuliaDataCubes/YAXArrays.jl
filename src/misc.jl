function normalize{T}(xin::AbstractVector{T},xout::AbstractVector,mask::AbstractVector)
  s=zero(T)
  s2=zero(T)*zero(T)
  n=0
  for i in eachindex(xin)
    if mask[i]==CABLAB.VALID
      s+=xin[i]
      s2+=xin[i]*xin[i]
      n+=1
    end
  end
  m=s/n
  v=s2-m*m
  for i in eachindex(xout)
    xout[i]=(xin[i]-m)/sqrt(v)
  end
end

@registerDATFunction normalize (TimeAxis,) TimeAxis
