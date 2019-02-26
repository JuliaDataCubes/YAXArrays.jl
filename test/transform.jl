using ESDL
using Test
using Statistics

@testset "Transformed cubes" begin
c=Cube()

@testset "ConcatCubes" begin
d1 = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = getCubeData(c,variable="gross_primary_productivity",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d3 = getCubeData(c,variable="net_ecosystem_exchange",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2007-12-31")))
conccube = concatenateCubes([d1,d2],CategoricalAxis("NewAxis",["v1","v2"]))
@test size(conccube)==(4,4,322,2)
@test ESDL.caxes(conccube)[1:3]==ESDL.caxes(d1)
@test ESDL.caxes(conccube)[4]==CategoricalAxis("NewAxis",["v1","v2"])
@test_throws ErrorException concatenateCubes([d1,d3],CategoricalAxis("NewAxis",["v1","v2"]))
dd1 = readcubedata(d1)
dd2 = readcubedata(d2)
aout = zeros(Float32,4,4,322,2)
mout = zeros(UInt8,4,4,322,2)
ddconc = readcubedata(conccube)
@test ddconc.data[:,:,:,1] == dd1.data
@test ddconc.data[:,:,:,2] == dd2.data
#@test isa(ESDL.Cubes.gethandle(conccube,(2,2,2,2)),ESDL.CubeAPI.CachedArrays.CachedArray)
@test mean(ddconc.data,dims=1)[1,:,:,:]==mapslices(mean∘skipmissing,conccube,"Lon").data
conccube2 = concatenateCubes([dd1,dd2],CategoricalAxis("NewAxis",["v1","v2"]))
#@test isa(ESDL.Cubes.gethandle(conccube2,(2,2,2,2)),Tuple{AbstractArray,AbstractArray})
@test mean(ddconc.data,dims=1)[1,:,:,:]==mapslices(mean∘skipmissing,conccube2,"Lon").data
end

@testset "SliceCubes" begin
d1 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = readcubedata(d1)
dd2 = SliceCube(d1,"Var","air")
dd3 = SliceCube(d1,TimeAxis,Date(2002,1,8))
dd4 = SliceCube(d1,LatAxis,50.625)
dd5 = SliceCube(d2,LonAxis,30.125)
#@test isa(ESDL.Cubes.gethandle(dd2,(2,2,2)),ESDL.CubeAPI.CachedArrays.CachedArray)
#@test isa(ESDL.Cubes.gethandle(dd5,(2,2,2)),Tuple{AbstractArray,AbstractArray})
@test ESDL.axes(dd2)==ESDL.axes(d1)[1:3]
@test ESDL.axes(dd3)==ESDL.axes(d1)[[1,2,4]]
@test ESDL.axes(dd4)==ESDL.axes(d1)[[1,3,4]]
@test ESDL.axes(dd5)==ESDL.axes(d1)[2:4]
@test readcubedata(dd2).data==d2.data[:,:,:,1]
@test readcubedata(dd3).data==d2.data[:,:,2,:]
@test readcubedata(dd4).data==d2.data[:,2,:,:]
@test readcubedata(dd5).data==d2.data[1,:,:,:]
end


end
