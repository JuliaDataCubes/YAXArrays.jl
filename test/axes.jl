using ESDL
using Base.Test

@testset "Axis generation" begin
@test LonAxis(1.0:10.0)==RangeAxis{Float64,:Lon,StepRangeLen{Float64}}(1.0:10.0)
@test LatAxis(1.0:10.0)==RangeAxis{Float64,:Lat,StepRangeLen{Float64}}(1.0:10.0)

r = ESDL.YearStepRange(Date("2001-01-01"),Date("2008-01-01"),Dates.Day(8))
@test r==ESDL.YearStepRange(2001,1,2008,1,8,46)

@test TimeAxis(r)==RangeAxis{Date,:Time,ESDL.YearStepRange}(r)
end
