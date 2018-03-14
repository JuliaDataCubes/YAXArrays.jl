module Outlier
export DAT_detectAnomalies!, simpleAnomalies
importall ..DAT
importall ..CubeAPI
importall ..Cubes
import ..Proc
using MultivariateAnomalies

function getDetectParameters(methodlist,trainarray,ntime)
  P = getParameters(methodlist,trainarray);
  init_detectAnomalies(zeros(Float64,ntime,size(trainarray,2)), P);
  (P,)
end

"""
    DAT_detectAnomalies!

A simple wrapper around the function `detectAnomalies!` from the [MultivariateAnomalies](https://github.com/milanflach/MultivariateAnomalies.jl)
package.

### Call signature

    mapCube(DAT_detectAnomalies!, cube, methods, trainArray)

* `cube` data cube with a axes: `TimeAxis`, `VariableAxis`
* `methods` vector of methods to be applied, choose from: `KDE`,`T2`,`REC`,`KNN-Gamma`,`KNN-Delta`,`SVDD`,`KNFST`
* `trainArray` a matrix of `nsample` x `nvar`, to estimate the training parameters for the model. Ideally does not contain any extreme values

**Input Axes** `TimeAxis`, `Variable`axis

**Output Axes** `TimeAxis`, `Method`axis

For an example on how to apply this function, see [this notebook](https://github.com/CAB-LAB/JuliaDatDemo/blob/master/eventdetection2.ipynb).
"""
function DAT_detectAnomalies!(xout::AbstractArray, xin::AbstractArray, P::MultivariateAnomalies.PARAMS)
 detectAnomalies!(Float64.(xin), P)
 for i = 1:length(P.algorithms)
   copy!(view(xout, :, i), MultivariateAnomalies.return_scores(i, P))
 end
 return(xout)
end
registerDATFunction(DAT_detectAnomalies!,
  indims = InDims(TimeAxis,VariableAxis,miss=NaNMissing()),
  outdims = OutDims(TimeAxis,(cube,pargs)->CategoricalAxis("Method",pargs[1]),miss=NaNMissing()),
  args = (cube,pargs)->getDetectParameters(pargs[1],pargs[2],length(getAxis(TimeAxis,cube[1].cube))),
  no_ocean=1)


function simpleAnomalies(xout::AbstractArray, xin::AbstractArray,methods)
  if !any(isnan,xin)
    P=getParameters(methods,xin)
    res=detectAnomalies(xin,P)
    for i=1:length(res)
      xout[:,i]=res[i]
    end
  else
    xout[:]=NaN
    end
end
registerDATFunction(simpleAnomalies,
  indims = InDims(TimeAxis,VariableAxis,miss=NaNMissing()),
  outdims = OutDims(TimeAxis,(cube,pargs)->CategoricalAxis("Method",pargs[1]),miss=NaNMissing()),
  no_ocean=1)

end
