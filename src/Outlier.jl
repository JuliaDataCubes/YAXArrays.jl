module Outlier
include("constants.jl")
funcfolder=joinpath(Pkg.dir("CABLAB"),"deps","hotspot_outlier_utility_functions","Milan","Julia_v0.4","functions")
include(joinpath(funcfolder,"distance_density.jl"))
include(joinpath(funcfolder,"evaluate_indices.jl"))
include(joinpath(funcfolder,"helpers.jl"))
include(joinpath(funcfolder,"outlier_scores.jl"))
checkvalid(x::UInt8)=(x>UInt8(0)) || (x & FILLED)==FILLED
function checkvalid(x::AbstractArray{UInt8})
  a=true
  for i in eachindex(x)
    checkvalid(x[i]) || (a=true;break)
  end
  a
end

function recurrences!(xin::AbstractMatrix, xout::AbstractVector, maskin::AbstractMatrix,maskout::AbstractVector,rec_threshold::Float64, temp_excl::Int,distmatspace::AbstractMatrix)
  checkvalid(maskin) || error("Data has missing values, please consider Gapfilling before calculating scores")
  pairwise!(distmatspace,Euclidean(),xin)
  recurrences!(xout,distmatspace,rec_threshold,temp_excl)
  xout
end

end
#import Outlier.recurrences!
#@registerDATFunction recurrences! (VariableAxis,TimeAxis) (TimeAxis,) rec_threshold::Float64 temp_excl::Int distmatspace::AbstractMatrix
