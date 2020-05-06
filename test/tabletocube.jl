using ESDL
using Test
using Dates
using IterTools
using WeightedOnlineStats

c=Cube()
d = subsetcube(c,variable=["air_temperature_2m", "gross_primary_productivity", "soil_moisture"],lon=(30,31),lat=(50,51),
              time=(Date("2002-01-01"),Date("2008-12-31")))
mytable = CubeTable(value=d,include_axes=("lon", "lat", "time"), expandaxes=("var",))

mytable2 = CubeTable(data=d,include_axes=("lon", "lat", "time", "variable"))

@testset "cubefittable and WeightedCovMatrix fittable" begin
    covmCube = cubefittable(mytable, WeightedCovMatrix, :value, weight=(x->cosd(x.lat)),showprog=false)
    covmVal = WeightedCovMatrix()
    for row in mytable
        obs = row.value
        obslat = row.lat
        if !any(ismissing.(obs))
            fit!(covmVal, obs, cosd(obslat))
        end
    end
    @test all(isapprox.(covmCube.data, value(covmVal)))
end

@testset "remaining functions in tablestats.jl" begin
    meanCube = cubefittable(mytable2, WeightedMean, :data, weight=(x->cosd(x.lat)),
                            by=(:variable,))
    weightedTableMeans = fittable(mytable2, WeightedMean, :data, by=(:variable,),
                                    weight=(x -> cosd(x.lat)))
    foreach(enumerate(["air_temperature_2m", "gross_primary_productivity", "soil_moisture"])) do (i,v)
      @test isapprox(value(weightedTableMeans)[(v,)], meanCube.data[i])
    end
end
