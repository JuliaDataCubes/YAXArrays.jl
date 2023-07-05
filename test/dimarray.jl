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

    @test r isa AbstractDimArray
    temp = tempname()
    @test_broken c_saved = savecube(c, temp)
    @test_broken c_saved isa AbstractDimArray 
    @test_broken all(c_saved[:,:,:] .== c[:,:,:])

    @test_broken c_reopened = open_dataset(temp, artype=DimArray) isa AbstractDimArray
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
    @test_broken mapslices(sum, yax, dims="axis1")
end

@testitem "Moving Window DimArray" begin
    using YAXArrays
    using DimensionalData
    a = Array{Union{Float64,Missing}}(rand(40, 20, 10))
    lon = Dim{:Lon}(1:40)
    lat = Dim{:Lat}(1:20)
    tim = Dim{:Time}(1:10)
    c = DimArray(a,(lon, lat, tim))

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
    @test r1 isa AbstractDimArray
    @test r2 isa AbstractDimArray
    @test r3 isa AbstractDimArray

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
    @test r1 isa AbstractDimArray
    @test r2 isa AbstractDimArray
    @test r3 isa AbstractDimArray

    a = Array{Union{Float64,Missing}}(rand(10,4,  40, 20));
    varax = Dim{:Variable}('a':'d')
    lon = Dim{:Lon}(1:40)
    lat = Dim{:Lat}(1:20)
    tim = Dim{:Time}(1:10)

    c = DimArray(a, (tim, varax, lon,lat))
    indims = InDims("Time",YAXArrays.MovingWindow("Lon",1,1))
    r1 = mapCube(c, indims=indims, outdims=OutDims("Time")) do xout,xin
        xout[:] = xin[:,1]
    end
    @test all(ismissing,r1[:,:,1,:])
    @test r1[:,:,2:40,:] == a[:,:,1:end-1,:]
    @test r1 isa AbstractDimArray
end

@testitem "DimArray Chunking" begin
    using YAXArrays 
    using DimensionalData

    a = Array{Union{Float64,Missing}}(rand(40, 20, 10))
    lon = Dim{:Lon}(1:40)
    lat = Dim{:Lat}(1:20)
    tim = Dim{:Time}(1:10)
    c = DimArray(a,(lon, lat, tim))
    d = tempname()
    @test_broken c_chunked = setchunks(c,Dict("Lon" => 7, "Lat" => 9))
    @test_broken c_chunked isa AbstractDimArray

end

@testitem "DimArray tablestats" begin
    using DimensionalData
    using YAXArrays 
    using OnlineStats
    data = collect(reshape(1:20.,4,5))
    axlist = (Dim{:XVals}(1.0:4.0), Dim{:YVals}([1,2,3,4,5]))
    props = Dict("att1"=>5, "att2"=>"Hallo")
    a = DimArray(data, axlist, metadata=props)
    cta = CubeTable(data=a)
    meancta = cubefittable(cta,Mean(),:data, by=(:YVals,))
    @test meancta.data == [2.5, 6.5, 10.5, 14.5, 18.5] 
    @test meancta isa AbstractDimArray 
    ashcta = cubefittable(cta, Ash(KHist(3)), :data, by=(:YVals,))
    @test all(ashcta[Hist=At("Frequency")][1,:] .== 0.2222222222222222)
    @test ashcta isa AbstractDimArray 
    khistcta = cubefittable(cta, KHist(3), :data, by=(:YVals,))
    @test all(khistcta[Dim{:Hist}(At("Frequency"))][1,:] .== 1.0)
    @test khistcta isa AbstractDimArray
end