@testitem "DimensionalData mapcube" begin
    using DimensionalData
    using YAXArrays
    m = Array{Union{Int, Missing}}(undef, 4,2,10)
    for i in 1:size(m,3)
        m[:,1,i] .= i
        m[:,2,i] .= 2*i
    end
    m[1,1,3] = missing
    m[3,1,6:10] .=missing
    m[4,1,:] .= 10

    lon = Dim{:Lon}(1:4)
    lat = Dim{:Lat}(1:2)
    tim = Dim{:Time}(1:10)
    c = DimArray(m, (lon, lat, tim))
    indims = InDims("Time")
    outdims = OutDims()
    r = mapCube(c, indims=indims, outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    anymiss = mapCube(c, indims=InDims("Time", filter=YAXArrays.DAT.AnyMissing()), outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test ismissing(anymiss[1,1])
    @test r[1,1] == 52
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

    @test_broken r isa DimArray
    temp = tempname()
    @test_broken c_saved = savecube(c, temp)
    @test_broken c_saved isa DimArray 
    @test_broken all(c_saved[:,:,:] .== c[:,:,:])

    @test_broken c_reopened = open_dataset(temp, artype=DimArray) isa DimArray
    @test_broken all(c_reopened.data .== c)
    @test_broken c.dims[1] == c_reopened.dims[1]
end

@testitem "Multiple Cubes" begin
    using YAXArrays 
    using DimensionalData
    x = Dim{:x}(1:4)
    y = Dim{:y}(1:5)
    z = Dim{:z}(1:6)
    a1 = DimArray(rand(4,5,6), (x,y,z))
    a2 = DimArray(rand(4,6,5),(x,z,y))
    a3 = DimArray(rand(4,5),(x,y))
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


    x = Dim{:axis1}(1:10)
    yax = DimArray(rand(10), x)
    r = mapslices(sum, yax, dims=:axis1)
    @test r.data[] == sum(yax.data)

    #I am not sure, whether this is an actual use case 
    # and whether we would like to support the mix of symbol and string axisnames.
    @test_broken r = mapslices(sum, yax, dims="axis1")
end