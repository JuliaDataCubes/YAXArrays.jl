module Outlier
funcfolder=joinpath(Pkg.dir(),"deps","hotspot_outlier_utility_functions","Milan","jl_functions","julia_v0.4","functions")
include(joinpath(funcfolder,"distance_density.jl"))
include(joinpath(funcfolder,"evaluate_indices.jl"))
include(joinpath(funcfolder,"helpers.jl"))
include(joinpath(funcfolder,"outlier_scores.jl"))

end
