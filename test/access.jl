using CABLAB
using Base.Test
#Open a remote cube
c=RemoteCube()

d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(DateTime("2002-01-01"),DateTime("2008-12-31")))

@test typeof(c)==RemoteCube
@test d.variable=="air_temperature_2m"
@test d.sub_grid==(157,160,841,844)
@test d.sub_times==(2002,1,2008,46,322,46)
@test d.lonAxis.values==30.0:0.25:30.75
@test d.latAxis.values==51.0:-0.25:50.25

d2 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(DateTime("2002-01-01"),DateTime("2008-12-31")))

@test d2.variable==["air_temperature_2m","gross_primary_productivity"]
@test d2.sub_grid==(157,160,841,844)
@test d2.sub_times==(2002,1,2008,46,322,46)
@test d2.lonAxis.values==30.0:0.25:30.75
@test d2.latAxis.values==51.0:-0.25:50.25

data1=readCubeData(d)
data2=readCubeData(d2)

@test size(data1.data)==(4,4,322)
@test size(data2.data)==(4,4,322,2)



@test isapprox(data1.data[1,1,1:10],Float32[265.345,270.253,270.838,276.829,278.678,
  277.004,274.693,276.203,280.781,278.062])

@test isapprox(data2.data[1,1,1:10,1],Float32[265.345,270.253,270.838,276.829,278.678,
  277.004,274.693,276.203,280.781,278.062])

@test CABLAB.axes(data1)==CubeAxis[LonAxis(30.0:0.25:30.75),LatAxis(51.0:-0.25:50.25),TimeAxis(CABLAB.Cubes.Axes.YearStepRange(2002,1,2008,46,8,46))]

@test CABLAB.axes(data2)==CubeAxis[LonAxis(30.0:0.25:30.75),LatAxis(51.0:-0.25:50.25),TimeAxis(CABLAB.Cubes.Axes.YearStepRange(2002,1,2008,46,8,46)),VariableAxis(["air_temperature_2m","gross_primary_productivity"])]
