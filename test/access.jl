using ESDL
using Test
using Dates
#Open a remote cube
@testset "Cube Access" begin

c=Cube()

@testset "Access single variable" begin
d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))

#@test typeof(c)==RemoteCube
@test d.variable=="air_temperature_2m"
@test d.sub_grid==(157,160,841,844)
@test d.sub_times==(2002,1,2008,46,322,46)
@test d.lonAxis.values==30.125:0.25:30.875
@test d.latAxis.values==50.875:-0.25:50.125
end

@testset "Access multiple variables" begin
d2 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

@test d2.variable==["air_temperature_2m","gross_primary_productivity"]
@test d2.sub_grid==(157,160,841,844)
@test d2.sub_times==(2002,1,2008,46,322,46)
@test d2.lonAxis.values==30.125:0.25:30.875
@test d2.latAxis.values==50.875:-0.25:50.125
end

@testset "Test values in MemCube" begin
d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
data1=readCubeData(d)
data2=readCubeData(d2)

@test size(data1.data)==(4,4,322)
@test size(data2.data)==(4,4,322,2)


@test isapprox(data1.data[1,1,1:10],Float32[265.345,270.253,270.838,276.829,278.678,
  277.004,274.693,276.203,280.781,278.062])

@test isapprox(data2.data[1,1,1:10,1],Float32[265.345,270.253,270.838,276.829,278.678,
  277.004,274.693,276.203,280.781,278.062])

@test caxes(data1)==CubeAxis[LonAxis(30.125:0.25:30.875),LatAxis(50.875:-0.25:50.125),TimeAxis(ESDL.Cubes.Axes.YearStepRange(2002,1,2008,46,8,46))]

@test caxes(data2)==CubeAxis[LonAxis(30.125:0.25:30.875),LatAxis(50.875:-0.25:50.125),TimeAxis(ESDL.Cubes.Axes.YearStepRange(2002,1,2008,46,8,46)),VariableAxis(["air_temperature_2m","gross_primary_productivity"])]

@test_throws ArgumentError getCubeData(c,longitude=(10,-10))
end

@testset "Coordinate extraction" begin
d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))
data1=readCubeData(d)
# Test reading of coordinate list
ll=[30.1 50.2;30.5 51.1;30.8 51.1]
llcube = extractLonLats(data1,ll)
@test llcube.data[1,:]==data1.data[1,4,:]
@test llcube.data[2,:]==data1.data[3,1,:]
@test llcube.data[3,:]==data1.data[4,1,:]
end

@testset "Accessing regions" begin
#Test access datacube by region
d3 = getCubeData(c,variable="gross_primary_productivity",region="Cambodia",time=Date("2005-01-01"))
@test d3.axes==[LonAxis(102.375:0.25:107.375),LatAxis(14.625:-0.25:10.625)]
end

@testset "Saving and loading cubes" begin
d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))
data1=readCubeData(d)
#Test saving cubes
dire=mktempdir()
ESDLdir(dire)
saveCube(data1,"mySavedCube")
data3=readCubeData(loadCube("mySavedCube"))
@test data1.axes==data3.axes
@test data1.data==data3.data
@test data1.mask==data3.mask
end
end
