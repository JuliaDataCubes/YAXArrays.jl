using CABLAB
using Base.Test

@testset "Transformed cubes" begin
c=RemoteCube()

@testset "ConcatCubes" begin
d1 = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = getCubeData(c,variable="gross_primary_productivity",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d3 = getCubeData(c,variable="net_ecosystem_exchange",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2007-12-31")))
conccube = concatenateCubes([d1,d2],CategoricalAxis("NewAxis",["v1","v2"]))
@test size(conccube)==(4,4,322,2)
@test CABLAB.axes(conccube)[1:3]==CABLAB.axes(d1)
@test CABLAB.axes(conccube)[4]==CategoricalAxis("NewAxis",["v1","v2"])
@test_throws ErrorException concatenateCubes([d1,d3],CategoricalAxis("NewAxis",["v1","v2"]))
dd1 = readCubeData(d1)
dd2 = readCubeData(d2)
aout = zeros(Float32,4,4,322,2)
mout = zeros(UInt8,4,4,322,2)
ddconc = readCubeData(conccube)
@test ddconc.data[:,:,:,1] == dd1.data
@test ddconc.data[:,:,:,2] == dd2.data
dnomsc = 
end


end
