using OnlineStats
using MultivariateStats
export cubePCA, rotation_matrix, transformPCA, explained_variance
function pcafromcov(xout,maskout,covs,covmask,means,meanmask;pratio=0.9,maxoutdim=3)
    if (covmask[1] & MISSING)==0x00
        xout[1] = pcacov(covs,copy(means),pratio=pratio,maxoutdim=maxoutdim)
        maskout[1] = VALID
    else
        maskout[1] = covmask[1]
    end
end

function pcapredict(xout,xin::Union{Vector,Matrix},pcain,pcamask,cfun)
    if (pcamask[1] & MISSING)==0x00
        ttransformed = transform(pcain,xin)
        xout[1:length(ttransformed)] = ttransformed
    else
        xout[:] = NaN
    end
end
function pcapredict(xout,xin::Array,pcain,pcamask,cfun)
    xout2 = reshape(xout,(size(xout,1),length(xout)÷size(xout,1)))
    xin2 = reshape(xin,(size(xin,1),length(xin)÷size(xin,1)))
    if (pcamask[1] & MISSING)==0x00
        ttransformed=transform(pcain,xin2)
        xout2[1:length(ttransformed)] = ttransformed
    else
        xout2[:] = NaN
    end
end
function pcapredict(xout,xin::Union{Vector,Matrix},pcain,pcamask,by,bymask,cfun::Function)
    if ((pcamask[1] | bymask) & MISSING)==0x00
        ttransformed = transform(pcain[cfun(by)],xin)
        xout[1:length(ttransformed)] = ttransformed
    else
        xout[:] = NaN
    end
end
function pcapredict(xout,xin::Array,pcain,pcamask,by,bymask,cfun::Function)
    xout2 = reshape(xout,(size(xout,1),length(xout)÷size(xout,1)))
    xin2 = reshape(xin,(size(xin,1),length(xin)÷size(xin,1)))
    @assert size(xout2,2)==size(xin2,2)
    xhelp = zeros(eltype(xin),size(xin,1))
    if (pcamask[1] & MISSING)==0x00
      for i=1:size(xin2,2)
        if ((bymask[i] & MISSING)==0x00)
          copy!(xhelp,view(xin2,:,i))
          ttransformed = transform(pcain[cfun(by[i])],xhelp)
                xout2[1:size(ttransformed,1),i] = ttransformed
        else
          xout2[:,i] = NaN
        end
      end
    else
        xout2[:] = NaN
    end
end
function explained_variance(xout,xin,inmask)
  pv = principalvars(xin)
  if size(pv)==size(xout)
    xout[:] = pv/sum(pv)
  else
    xout[:] = NaN
  end
end
function rotation(xout,xin,inmask)
  p=projection(xin)
  if size(p)==size(xout)
    xout[:]=p
  else
    xout[:]=NaN
  end
end

"""
    type OnlinePCA

Represents the result of an Online PCA calculated on a DataCube.
"""
type OnlinePCA
  PCA::CubeMem
  noutdims::Int
  varAx
  varAx1
  varAx2
  bycube::Vector
end
import Base.show
function show(io::IO,c::OnlinePCA)
  println(io,"Online PCA result, you can call `explained_variance` to extract explained variances, `rotation` to retrieve the rotation matrix or `transform` to project data using the PCA.")
end
PCAxis(n)=CategoricalAxis("PC",["PC $i" for i=1:n])

"""
    cubePCA(cube::AbstractCubeData)

Performs a PCA based on a covariance matrix which is estimated through an online algorithm.
Returns an OnlinePCA object from which [explained_variance](@ref) and the [rotation](@ref) can be extracted,
or which can be used to perform the projection on a dataset.


### Keyword arguments
* `MDAxis` specifies the axes that is reduced through the PCA
* `by` a vector of axes types or masks denoting if several PCAs should be performed. If provided, several PCAs will be performed.
* `noutdims` number of output dimensions, how many PCs are estimated

"""
function cubePCA(cube::AbstractCubeData;MDAxis=VariableAxis,by=CubeAxis[],max_cache=1e7,noutdims=3,kwargs...)
    covmat,means = mapCube(CovMatrix,cube,MDAxis=MDAxis,by=by)
    varAx  = getAxis(MDAxis,cube)
    varAx1 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 1"),varAx.values) : RangeAxis(string(axname(varAx)," 1"),varAx.values)
    varAx2 = isa(varAx,CategoricalAxis) ? CategoricalAxis(string(axname(varAx)," 2"),varAx.values) : RangeAxis(string(axname(varAx)," 2"),varAx.values)
    T      = eltype(covmat)

    pcares = mapCube(pcafromcov,(covmat,means),indims=((typeof(varAx1),typeof(varAx2)),(MDAxis,)),outdims=((),),outtype=(PCA{T},),
                genOut=(i->PCA(zeros(T,0),zeros(T,0,0),zeros(T,0),zero(T),zero(T)),);maxoutdim=noutdims,pratio=1.0)
    return OnlinePCA(pcares,noutdims,varAx,varAx1,varAx2,filter(i->!isa(i,DataType),by))
end

"""
    transformPCA(pca::OnlinePCA,c::AbstractCubeData)

Forward transform of a data cube `c` using a previously defined [OnlinePCA](@ref) object. The
The cube must contain the `MDAxis` as provided during PCA estimation as well as all axes
used as a `by argument`. Returns a transformed datacube.
"""
function transformPCA(pca::OnlinePCA,c::AbstractCubeData;max_cache=1e7,kwargs...)
    #Now determine how to brodcast for projection
    forbiddenAxes = CubeAxis[pca.varAx]
    axl=filter(i->in(i,axes(pca.PCA)),axes(c))
    isempty(axl) || push!(forbiddenAxes,axl...)
    if length(pca.bycube)==1
      # We have to decide if the pca is already split along the bycube or not
      haskey(pca.bycube[1].properties,"labels") || error("By cube does not have a label property")
      idict=pca.bycube[1].properties["labels"]
      axname=get(pca.bycube[1].properties,"name","Label")
      outAxis=CategoricalAxis(axname,collect(String,values(idict)))
      const convertdict=Dict(k=>i for (i,k) in enumerate(keys(idict)))
      cfun=x->convertdict[x]
      indata=(c,pca.PCA,pca.bycube[1])
      indimspca = [outAxis,]
      inmissing = (:nan,:mask,:mask)
      lout = length(outAxis)
      push!(forbiddenAxes,filter(i->!in(i,axes(pca.bycube[1])),axes(c))...)
      push!(forbiddenAxes,outAxis)
    else
      cfun = identity
      indata = (c,pca.PCA)
      inmissing = (:nan,:mask)
      indimspca = []
      lout = 1
    end
    inAxes2 = filter(a->!in(a,forbiddenAxes),axes(c))
    axcombs=combinations(inAxes2)
    totlengths=map(a->prod(map(length,a)),axcombs)*sizeof(Float32)*length(pca.varAx)
    smallenough=totlengths.<max_cache
    axcombs=collect(axcombs)[smallenough]
    totlengths=totlengths[smallenough]
    ia = isempty(totlengths) ? [] : map(typeof,axcombs[findmax(totlengths)[2]])
    indims = isempty(pca.bycube) ? (totuple([typeof(pca.varAx);ia]),()) : (totuple([typeof(pca.varAx);ia]),totuple(typeof.(indimspca)),totuple(ia))
    outdims = (totuple([PCAxis(pca.noutdims);ia]),)
    pcpred = mapCube(pcapredict,indata,cfun,indims=indims,outdims=outdims,outtype=(Float32,),inmissing=inmissing,outmissing=(:nan,),max_cache=max_cache;kwargs...)
    pcpred
end

"""
    explained_variance(c::OnlinePCA)

Returns the relative explained variance of each PC as a datacube.
"""
explained_variance(c::OnlinePCA) = mapCube(explained_variance,(c.PCA,),indims=((),),outdims=((PCAxis(c.noutdims),),),outtype=(Float32,),inmissing=(:mask,),outmissing=(:nan,))

"""
    rotation_matrix(c::OnlinePCA)

Returns the rotations matrix as a datacube.
"""
rotation_matrix(c::OnlinePCA)    = mapCube(rotation,(c.PCA,),indims=((),),outdims=((c.varAx,PCAxis(c.noutdims)),),outtype=(Float32,),inmissing=(:mask,),outmissing=(:nan,))


#End
