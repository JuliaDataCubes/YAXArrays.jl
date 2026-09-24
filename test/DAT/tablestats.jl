using OnlineStats
using Distributed

@testset "cubefittable" begin

data = collect(reshape(1:20.,4,5))
axlist = (Dim{:XVals}(1.0:4.0), Dim{:YVals}([1,2,3,4,5]))
props = Dict("att1"=>5, "att2"=>"Hallo")
a = YAXArray(axlist, data, props)


cta = CubeTable(data=a)
meancta = cubefittable(cta,Mean(),:data, by=(:YVals,))
@test meancta.data == [2.5, 6.5, 10.5, 14.5, 18.5] 

ashcta = cubefittable(cta, Ash(KHist(3)), :data, by=(:YVals,))
# all(ashcta[Hist=At("Frequency")][1,:] .== 0.2222222222222222)

khistcta = cubefittable(cta, KHist(3), :data, by=(:YVals,))
# all(khistcta[Hist=At("Frequency")][1,:] .== 1.0)

end

@testset "cubefittable distributed" begin

data = collect(reshape(1:20.,4,5))
axlist = (Dim{:XVals}(1.0:4.0), Dim{:YVals}([1,2,3,4,5]))
a = YAXArray(axlist, data)

# Shrink the cache so the tiny table is split into several chunks, otherwise
# fittable takes the single-chunk serial path and the workers are never used.
oldcache = YAXArrays.YAXDefaults.max_cache[]
YAXArrays.YAXDefaults.max_cache[] = 64.0
cta = CubeTable(data=a)
YAXArrays.YAXDefaults.max_cache[] = oldcache
@test length(cta) > 1

# serial reference results
meanserial = cubefittable(cta, Mean(), :data, by=(:YVals,))
sumserial = cubefittable(cta, Sum(), :data, by=(:YVals,))
varserial = cubefittable(cta, Variance(), :data, by=(:YVals,))

pids = addprocs(2; exeflags="--project=$(Base.active_project())")
try
    @everywhere using YAXArrays, OnlineStats
    @test nworkers() == 2

    meanpar = cubefittable(cta, Mean(), :data, by=(:YVals,))
    @test meanpar.data == [2.5, 6.5, 10.5, 14.5, 18.5]
    @test meanpar.data == meanserial.data

    sumpar = cubefittable(cta, Sum(), :data, by=(:YVals,))
    @test sumpar.data == [10.0, 26.0, 42.0, 58.0, 74.0]
    @test sumpar.data == sumserial.data

    varpar = cubefittable(cta, Variance(), :data, by=(:YVals,))
    @test varpar.data ≈ varserial.data

    # adaptive histograms merge across workers; only check shape, not bin placement
    khistpar = cubefittable(cta, KHist(3), :data, by=(:YVals,))
    @test size(khistpar) == (3, 2, 5)
finally
    rmprocs(pids)
end

end
