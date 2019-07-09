using ESDL
using Test

@testset "Axis generation" begin
@test LonAxis(1.0:10.0)==RangeAxis{Float64,:Lon,StepRangeLen{Float64}}(1.0:10.0)
@test LatAxis(1.0:10.0)==RangeAxis{Float64,:Lat,StepRangeLen{Float64}}(1.0:10.0)
end
