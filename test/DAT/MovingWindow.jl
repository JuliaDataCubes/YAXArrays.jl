@testset "MovingWindow" begin
    using Zarr
    a = Array{Union{Float64,Missing}}(rand(40, 20, 10))
    lon = RangeAxis("Lon", 1:40)
    lat = RangeAxis("Lat", 1:20)
    tim = RangeAxis("Time", 1:10)
    c = YAXArray([lon, lat, tim], a)
    d = tempname()
    c = savecube(c, d, chunksize = Dict("Lon" => 7, "Lat" => 9), backend = :zarr)

    indims = InDims("Time", MovingWindow("Lon", 1, 1), window_oob_value = -9999.0)
    r1 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 1]
    end
    r2 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 2]
    end
    r3 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 3]
    end
    @test r1.data[:, 2:40, :] == permutedims(a[1:39, :, :], (3, 1, 2))
    @test all(==(-9999.0), r1.data[:, 1, :])
    @test r2.data[:, :, :] == permutedims(a[:, :, :], (3, 1, 2))
    @test r3.data[:, 1:39, :] == permutedims(a[2:40, :, :], (3, 1, 2))
    @test all(==(-9999.0), r3.data[:, 40, :])

    indims = InDims("Time", MovingWindow("Lon", 1, 1), MovingWindow("Lat", 1, 1))
    r1 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 1, 1]
    end
    r2 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 2, 2]
    end
    r3 = mapCube(c, indims = indims, outdims = OutDims("Time")) do xout, xin
        xout[:] = xin[:, 3, 3]
    end
    @test r1.data[:, 2:40, 2:20] == permutedims(a[1:39, 1:19, :], (3, 1, 2))
    @test all(ismissing, r1.data[:, 1, :])
    @test all(ismissing, r1.data[:, :, 1])
    @test r2.data[:, :, :] == permutedims(a, (3, 1, 2))
    @test r3.data[:, 1:39, 1:19] == permutedims(a[2:40, 2:20, :], (3, 1, 2))
    @test all(ismissing, r3.data[:, end, :])
    @test all(ismissing, r3.data[:, :, end])

end
