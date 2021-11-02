@testset "Process Filter" begin
    m = Array{Union{Int, Missing}}(undef, 4,2,10)
    for i in 1:size(m,3)
        m[:,1,i] .= i
        m[:,2,i] .= 2*i
    end
    m[1,1,3] = missing
    m[3,1,6:10] .=missing
    m[4,1,:] .= 10
    lon = RangeAxis("Lon", 1:4)
    lat = RangeAxis("Lat", 1:2)
    tim = RangeAxis("Time", 1:10)
    c = YAXArray([lon, lat, tim], m)
    indims = InDims("Time")
    outdims = OutDims()
    r = mapCube(c, indims=indims, outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test r[1,1] == 52

    anymiss = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.AnyMissing()), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test ismissing(anymiss[1,1])

    filt(x) = all(iseven.(x))
    allevensum = mapCube(c, indims=InDims("Time", filter=filt), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test ismissing(allevensum[1,2,1])
    
    validmiss = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.NValid(6)), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test ismissing(validmiss[3,1])

    validcheck = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.NValid(4)), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test validcheck[3,1] == 15

    stdzero = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.StdZero()), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test ismissing(stdzero[4,1])

    nofilter = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.NoFilter()), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test any(ismissing.(nofilter.data)) == false
end