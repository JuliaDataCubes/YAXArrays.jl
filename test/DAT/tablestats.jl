using OnlineStats

@testset "cubefittable" begin
    
data = collect(reshape(1:20,4,5))
axlist = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5])]
props = Dict("att1"=>5, "att2"=>"Hallo")
a = YAXArray(axlist, data, props)

ca = CubeTable( data=a, include_axes=("XVals", "YVals"))
fita = cubefittable(ca,Mean(),:data, by=(:YVals,))
@test fita.data == [2.5, 6.5, 10.5, 14.5, 18.5] 
end
