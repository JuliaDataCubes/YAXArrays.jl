module Outlier
export recurrences, DAT_detectAnomalies!
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

function DAT_detectAnomalies!(xout::AbstractArray, xin::AbstractArray, P::MultivariateAnomalies.PARAMS)
 detectAnomalies!(xin, P)
 for i = 1:length(P.algorithms)
   copy!(sub(xout, :, i), MultivariateAnomalies.return_scores(i, P))
 end
 return(xout)
end
registerDATFunction(DAT_detectAnomalies!,(TimeAxis,VariableAxis),(TimeAxis,(cube,pargs)->MethodAxis(pargs[1])),
(cube,pargs)->getDetectParameters(pargs[1],pargs[2],length(Proc.Stats.getAxis(cube[1],TimeAxis))),inmissing=(:nan,),outmissing=:nan,no_ocean=1)


end
