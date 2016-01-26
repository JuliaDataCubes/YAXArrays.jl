module Outlier
export recurrences!
using ..DAT
using ..CubeAPI

funcfolder=joinpath(Pkg.dir("CABLAB"),"deps","hotspot_outlier_utility_functions","Milan","Julia_v0.4","functions")
include(joinpath(funcfolder,"distance_density.jl"))
include(joinpath(funcfolder,"evaluate_indices.jl"))
include(joinpath(funcfolder,"helpers.jl"))
include(joinpath(funcfolder,"outlier_scores.jl"))


function recurrences!(xin::AbstractMatrix, xout::AbstractVector, maskin::AbstractMatrix,maskout::AbstractVector,rec_threshold::Float64, temp_excl::Int,distmatspace::AbstractMatrix)
  isvalidorfilled(maskin) || error("Data has missing values, please consider Gapfilling before calculating scores")
  pairwise!(distmatspace,Euclidean(),xin)
  recurrences!(xout,distmatspace,rec_threshold,temp_excl)
  xout
end

@registerDATFunction recurrences! (VariableAxis,TimeAxis) (TimeAxis,) rec_threshold::Float64 temp_excl::Int distmatspace::AbstractMatrix

end
