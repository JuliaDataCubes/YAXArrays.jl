struct HistogramCube{T<:AbstractCubeData}
  c::T
end

plotHist(c::HistogramCube)=plotScatter(tohist(c.c),vsaxis="Hist",xaxis="MidPoints",yaxis="Frequency",alongaxis="Bin")

function tohist(d::HistogramCube)
  c=d.c
  nbins=length(OnlineStats.value(c.data[1])[1])
  cout=zeros(Float32,nbins,2,size(c.data)...)
  maskout=zeros(UInt8,nbins,2,size(c.data)...)
  for ii in CartesianRange(size(c.data))
    midp,v = OnlineStats.value(c.data[ii])
    cout[:,1,ii]=v
    cout[:,2,ii]=midp
    maskout[:,1,ii]=c.mask[ii]
    maskout[:,2,ii]=c.mask[ii]
  end
  classAx=CategoricalAxis("Bin",1:nbins)
  histAx=CategoricalAxis("Histogram",["Frequency","MidPoints"])
  CubeMem(CubeAxis[classAx,histAx,c.axes...],cout,maskout)
end

function Base.quantile(d::HistogramCube,q::Number)
  c=d.c
  cout=zeros(Float32,size(c.data)...)
  maskout=zeros(UInt8,size(c.data)...)
  for ii in CartesianRange(size(c.data))
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
  for ii in CartesianRange(size(c.data))
    qu = OnlineStats.quantile(c.data[ii],q)
    cout[:,ii]=qu
    maskout[:,ii]=c.mask[ii]
  end
  quantileax=CategoricalAxis("Quantile",collect(q))
  CubeMem(CubeAxis[quantileax,c.axes...],cout,maskout)
end
Base.quantile(d::AbstractCubeData,q;nbins=100,kwargs...) = quantile(mapCube(Hist,d,nbins;kwargs...),q)

using OnlineStats
getGenFun{T<:OnlineStats.Hist}(f::Type{T},nbins)=i->f(nbins)
getFinalFun{T<:OnlineStats.Hist}(f::Type{T},funargs...)=c->HistogramCube(c)
