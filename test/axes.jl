using CABLAB
using Base.Test

@test LonAxis(1.0:10.0)==RangeAxis{Float64,:Lon,FloatRange{Float64}}(1.0:10.0)
@test LatAxis(1.0:10.0)==RangeAxis{Float64,:Lat,FloatRange{Float64}}(1.0:10.0)

r = CABLAB.YearStepRange(Date("2001-01-01"),Date("2008-01-01"),Dates.Day(8))
@test r==CABLAB.YearStepRange(2001,1,2008,1,8,46)

@test TimeAxis(r)==RangeAxis{Date,:Time,CABLAB.YearStepRange}(r)
