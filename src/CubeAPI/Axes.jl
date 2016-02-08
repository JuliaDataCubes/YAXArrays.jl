module Axes
export CubeAxis, TimeAxis, VariableAxis, LonAxis, LatAxis, CountryAxis, SpatialPointAxis
abstract CubeAxis
immutable TimeAxis <: CubeAxis
  values::Vector{DateTime}
end
immutable VariableAxis <: CubeAxis
  values::Vector{UTF8String}
end
immutable LonAxis <: CubeAxis
  values::FloatRange{Float64}
end
immutable LatAxis <: CubeAxis
  values::FloatRange{Float64}
end
immutable SpatialPointAxis <: CubeAxis
  values::Vector{Tuple{Float64,Float64}}
end
immutable CountryAxis<: CubeAxis
  values::Vector{UTF8String}
end
Base.length(a::CubeAxis)=length(a.values)
end
