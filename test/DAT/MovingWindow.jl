@testset "MovingWindow" begin
    using Zarr
    a = Array{Union{Float64,Missing}}(rand(40, 20, 10))
    lon = RangeAxis("Lon", 1:40)
    lat = RangeAxis("Lat", 1:20)
    tim = RangeAxis("Time", 1:10)
    c = YAXArray([lon, lat, tim], a)
    d = tempname()
    c = savecube(setchunks(c,Dict("Lon" => 7, "Lat" => 9)), d, backend = :zarr)

    indims = InDims("Time",YAXArrays.MovingWindow("Lon",1,1),window_oob_value = -9999.0)
    r1 = mapCube(c, indims=indims, outdims=OutDims("Time")) do xout,xin
        xout[:] = xin[:,1]
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

    indims = InDims("Time",YAXArrays.MovingWindow("Lon",1,1),YAXArrays.MovingWindow("Lat",1,1))
    r1 = mapCube(c, indims=indims, outdims=OutDims("Time")) do xout,xin
        xout[:] = xin[:,1,1]
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

    a = Array{Union{Float64,Missing}}(rand(10,4,  40, 20));
    varax = CategoricalAxis("Variable", 'a':'d')
    tim = RangeAxis("Time", 1:10)
    lon = RangeAxis("Lon", 1:40)
    lat = RangeAxis("Lat", 1:20)
    c = YAXArray([tim, varax, lon,lat], a)
    indims = InDims("Time",YAXArrays.MovingWindow("Lon",1,1))
    r1 = mapCube(c, indims=indims, outdims=OutDims("Time")) do xout,xin
        xout[:] = xin[:,1]
    end
    @test all(ismissing,r1[:,:,1,:])
    @test r1[:,:,2:40,:] == a[:,:,1:end-1,:]

end
