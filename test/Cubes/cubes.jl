using YAXArrays, Test, Dates

@testset "YAXArrays" begin
    data = collect(reshape(1:20,4,5))
    axlist = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5])]
    props = Dict("att1"=>5, "att2"=>"Hallo")
    a = YAXArray(axlist, data, props)
    @test size(a) == (4,5)
    @test size(a,1) == 4
    @test size(a,2) == 5
    @test_throws ArgumentError YAXArray(axlist[1:1], data, props)
    @test_throws ArgumentError YAXArray([RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4])],data,props)
end
