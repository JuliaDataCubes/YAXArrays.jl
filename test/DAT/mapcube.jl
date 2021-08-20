@testset "mapcube" begin
    @testset "Loop Axis permutation" begin
        x,y,z = (RangeAxis("x",1:4), RangeAxis("y", 1:5), RangeAxis("z", 1:6))
        a1 = YAXArray([x,y,z], rand(4,5,6))
        a2 = YAXArray([x,z,y], rand(4,6,5))
        a3 = YAXArray([x,y], rand(4,5))
        indims = InDims("x")
        outdims = OutDims("x")
        r = mapCube((a1, a2), indims=(indims, indims), outdims=outdims) do xout, x1, x2
            xout .= x1 .+ x2
        end
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))
        r = mapCube((a2, a3), indims=(indims, indims), outdims=outdims) do xout, x1, x2
            xout .= x1 .+ x2
        end
        @test r.data == a2.data .+ reshape(a3.data,(4,1,5))
    end

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
end