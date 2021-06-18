using OnlineStats

@testset "cubefittable" begin
    
data = collect(reshape(1:20.,4,5))
axlist = [RangeAxis("XVals",1.0:4.0), CategoricalAxis("YVals",[1,2,3,4,5])]
props = Dict("att1"=>5, "att2"=>"Hallo")
a = YAXArray(axlist, data, props)

cta = CubeTable( data=a, include_axes=("XVals", "YVals"))
meancta = cubefittable(cta,Mean(),:data, by=(:YVals,))
@test meancta.data == [2.5, 6.5, 10.5, 14.5, 18.5] 

ashcta = cubefittable(cta, Ash(KHist(3)), :data, by=(:YVals,))
@test all(ashcta[Hist="Frequency"][1,:] .== 0.2222222222222222)

khistcta = cubefittable(cta, KHist(3), :data, by=(:YVals,))
@test all(khistcta[Hist="Frequency"][1,:] .== 1.0)

end
