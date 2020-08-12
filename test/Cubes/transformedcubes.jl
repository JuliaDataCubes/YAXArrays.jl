@testset "Transformed cubes" begin
    @testset "Simple map" begin
    data = collect(reshape(1:20,4,5))
    axlist = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5])]
    props = Dict("att1"=>5, "att2"=>"Hallo")
    a = YAXArray(axlist, data, props)
    a2 = map(i->i+1, a)
    @test all(a2.data .== a.data .+1)
    @test a2.axes == a.axes
    @test a2.properties==a.properties
    #TODO: Test that cleaners get promoted properly
    a3 = map(+,a,a2)
    @test all(a3.data .== a.data .+ a2.data)
    @test a3.axes == a.axes
    @test a3.properties==a.properties
    end
end
