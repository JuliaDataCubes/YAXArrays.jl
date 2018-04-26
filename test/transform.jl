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
@test isa(CABLAB.Cubes.gethandle(conccube,(2,2,2,2)),CABLAB.CubeAPI.CachedArrays.CachedArray)
@test mean(ddconc.data,1)[1,:,:,:]==reduceCube(mean,conccube,LonAxis,skipmissing=true).data
conccube2 = concatenateCubes([dd1,dd2],CategoricalAxis("NewAxis",["v1","v2"]))
@test isa(CABLAB.Cubes.gethandle(conccube2,(2,2,2,2)),Tuple{AbstractArray,AbstractArray})
@test mean(ddconc.data,1)[1,:,:,:]==reduceCube(mean,conccube2,LonAxis,skipmissing=true).data
end

@testset "SliceCubes" begin
d1 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = readCubeData(d1)
dd2 = SliceCube(d1,"Var","air")
dd3 = SliceCube(d1,TimeAxis,Date(2002,1,8))
dd4 = SliceCube(d1,LatAxis,50.625)
dd5 = SliceCube(d2,LonAxis,30.125)
@test isa(CABLAB.Cubes.gethandle(dd2,(2,2,2)),CABLAB.CubeAPI.CachedArrays.CachedArray)
@test isa(CABLAB.Cubes.gethandle(dd5,(2,2,2)),Tuple{AbstractArray,AbstractArray})
@test CABLAB.axes(dd2)==CABLAB.axes(d1)[1:3]
@test CABLAB.axes(dd3)==CABLAB.axes(d1)[[1,2,4]]
@test CABLAB.axes(dd4)==CABLAB.axes(d1)[[1,3,4]]
@test CABLAB.axes(dd5)==CABLAB.axes(d1)[2:4]
@test readCubeData(dd2).data==d2.data[:,:,:,1]
@test readCubeData(dd3).data==d2.data[:,:,2,:]
@test readCubeData(dd4).data==d2.data[:,2,:,:]
@test readCubeData(dd5).data==d2.data[1,:,:,:]
end


end
