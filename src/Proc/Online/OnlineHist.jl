import Statistics: quantile

struct HistogramCube{T<:AbstractCubeData}
  c::T
end

function tohist(d::HistogramCube)
  c=d.c
  nbins=length(OnlineStats.value(c.data[1])[1])
  cout=zeros(Float32,nbins,2,size(c.data)...)
  maskout=zeros(UInt8,nbins,2,size(c.data)...)
  for ii in CartesianIndices(size(c.data))
    if OnlineStats.nobs(c.data[ii])>0
      midp,v = OnlineStats.value(c.data[ii])
      cout[:,1,ii]=v
      cout[:,2,ii]=midp
      maskout[:,1,ii]=c.mask[ii]
      maskout[:,2,ii]=c.mask[ii]
    else
      cout[:,1,ii]=1:size(cout,1)
      cout[:,2,ii]=1:size(cout,1)
      maskout[:,:,ii]=0x01
    end
  end
  classAx=CategoricalAxis("Bin",1:nbins)
  histAx=CategoricalAxis("Histogram",["Frequency","MidPoints"])
  CubeMem(CubeAxis[classAx,histAx,c.axes...],cout,maskout)
end

function quantile(d::HistogramCube,q::Number)
  c=d.c
  cout=zeros(Float32,size(c.data)...)
  maskout=zeros(UInt8,size(c.data)...)
  for ii in CartesianIndices(size(c.data))
    qu = OnlineStats.quantile(c.data[ii],q)
    cout[ii]=qu
    maskout[ii]=c.mask[ii]
  end
  CubeMem(CubeAxis[c.axes...],cout,maskout)
end

function Base.quantile(d::HistogramCube,q)
  c=d.c
  cout=zeros(Float32,length(q),size(c.data)...)
  maskout=zeros(UInt8,length(q),size(c.data)...)
  for ii in CartesianIndices(size(c.data))
    if OnlineStats.nobs(c.data[ii])>0
      qu = OnlineStats.quantile(c.data[ii],q)
      cout[:,ii]=qu
      maskout[:,ii]=c.mask[ii]
    else
      cout[:,ii]=q
      maskout[:,ii]=0x01
    end
  end
  quantileax=CategoricalAxis("Quantile",collect(q))
  CubeMem(CubeAxis[quantileax,c.axes...],cout,maskout)
end
Base.quantile(d::AbstractCubeData,q;nbins=100,kwargs...) = quantile(mapCube(Hist,d,nbins;kwargs...),q)

using OnlineStats
getGenFun(f::Type{T},nbins) where {T<:OnlineStats.Hist}=i->f(nbins)
getFinalFun(f::Type{T},funargs...) where {T<:OnlineStats.Hist}=c->HistogramCube(c)
