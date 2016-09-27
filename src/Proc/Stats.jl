module Stats
export normalize, timeVariance, timeMean, spatialMean, timespacequantiles, timelonlatquantiles
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
        s+=xin[ilon,ilat]*w
        sw+=w
      end
    end
  end
  xout[1]=s/sw
end

function getAxis{T<:CubeAxis}(cube::AbstractCubeData,a::Type{T})
  for ax in axes(cube)
      isa(ax,a) && return ax
  end
  error("Axis $a not found in $(axes(cube))")
end

function nanquantile!(qout,x,q,xtest)
    copy!(xtest,x)
    nNaN  = 0; for i=1:length(xtest) nNaN = isnan(xtest[i]) ? nNaN+1 : nNaN end
    lv=length(xtest)-nNaN
    lv==0 && return(qout[:]=convert(eltype(x),NaN))
    sort!(reshape(x,length(x)))
    for iq=1:length(q)
        index = 1 + (lv-1)*q[iq]
        lo = floor(Int,index)
        hi = ceil(Int,index)
        h=index - lo
        lo==hi && return(qout[iq])
        qout[iq] = (1.0-h)*x[lo] + h*x[hi]
    end
end

function timespacequantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
    nanquantile!(xout,xin,q,xtest)
end
function timelonlatquantiles(xout::AbstractVector,xin::AbstractArray,q::AbstractVector,xtest)
    nanquantile!(xout,xin,q,xtest)
end
import CABLAB.Proc.MSC.getNpY


registerDATFunction(timelonlatquantiles,(TimeAxis,LonAxis,LatAxis),
  ((cube,pargs)->begin
    length(pargs)==0 ? QuantileAxis([0.25,0.5,0.75]) : QuantileAxis(pargs[1])
  end,),
  (cube,pargs)->begin
    tax=getAxis(cube[1],TimeAxis)
    lonax=getAxis(cube[1],LonAxis)
    latax=getAxis(cube[1],LatAxis)
    return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1]),length(tax),length(lonax),length(latax))
  end,inmissing=(:nan,),outmissing=:nan)

registerDATFunction(timespacequantiles,(TimeAxis,SpatialPointAxis),
  ((cube,pargs)->begin
    length(pargs)==0 ? QuantileAxis([0.25,0.5,0.75]) : QuantileAxis(pargs[1])
  end,),
  (cube,pargs)->begin
    tax=getAxis(cube[1],TimeAxis)
    sax=getAxis(cube[1],SpatialPointAxis)
    return length(pargs)==1 ? pargs[1] : [0.25,0.5,0.75],zeros(eltype(cube[1]),length(tax),length(sax))
  end,inmissing=(:nan,),outmissing=:nan)

registerDATFunction(spatialMean,((LonAxis,LatAxis),(LatAxis,)),())
registerDATFunction(normalize,(TimeAxis,),(TimeAxis,))
registerDATFunction(timeMean,(TimeAxis,),())
registerDATFunction(timeVariance,(TimeAxis,),())



end
