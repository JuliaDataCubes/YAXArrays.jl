@testitem "xmap" begin
    using YAXArrays
    using DimensionalData
    @testset "Loop Axis permutation" begin
        x,y,z = X(1:4), Y(1:5), Z(1:6)
        a1 = YAXArray((x,y,z), rand(4,5,6))
        a2 = YAXArray((x,z,y), rand(4,6,5))
        a3 = YAXArray((x,y), rand(4,5))
        r = xmap(a1 ⊘ :X, a2 ⊘ :X, output = XOutput(dims(a1, X))) do xout, x1, x2
            xout .= x1 .+ x2
        end
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))
        r = xmap(a2 ⊘ :X, a3 ⊘ :X, output=XOutput(dims(a1, X))) do xout, x1, x2
            xout .= x1 .+ x2
        end
        @test r.data == a2.data .+ reshape(a3.data,(4,1,5))
        #r = xmap(a2 ⊘ X, a3 ⊘ X, output=XOutput(dims(a1, X)),nthreads = [1]) do xout, x1, x2
        #    xout .= x1 .+ x2
        #end
        @test r.data == a2.data .+ reshape(a3.data,(4,1,5))
    end
    @testset "Disconnected Graphs" begin
        using Test
        using YAXArrays
        a1 = YAXArray((Dim{:d1}(1:10),), 1:10)
        a2 = YAXArray((Dim{:d2}(1:20),), 1:20)
        Xmap.LAZY_INMEMORY_XMAP[] = true
        outds = Dataset(a=a1 .* 2, b=a2 .+ 5)
        @test outds.a.data isa YAXArrays.Xmap.DAE.GMWOPResult
        @test outds.b.data isa YAXArrays.Xmap.DAE.GMWOPResult
        outpath = tempname()
        isfile(outpath)
        dsdisk = compute_to_zarr(outds, outpath)
        @test dsdisk.a[:] == 2:2:20
        @test dsdisk.b[:] == 6:25
    end
end
@testitem "set outtype" begin
    using YAXArrays
    using DimensionalData
    x,y,z = X(1:4), Y(1:5), Z(1:6)
    a1 = YAXArray((x,y,z), rand(UInt8, 4,5,6))
    r = xmap((xout, xin) -> xout .= sum(xin), a1 ⊘ :X, output=XOutput(outtype=Float16))
    @test r.data == Float16.(sum(a1.data, dims=1))
end

@testitem "time axis with different type should be broadcastable" begin
    using Dates
    using YAXArrays
    using DimensionalData
    using Logging
    t1 = Time(0):Hour(1):Time(23)
    data = rand(24)
    a = YAXArray((YAXArrays.time(t1),), data)
    b = YAXArray((Dim{:time}(t1),), data)
    c = @test_logs min_level=Logging.Warn a .- b
    @test all(c[:] .== 0)
end

@testitem "xresample with AbstractDimArray" begin
    using YAXArrays
    using DimensionalData
    using DimensionalData: DimensionalData as DD, DimArray
    using DiskArrayEngine: DiskArrayEngine as DAE
    coarsedata = reshape(1:16, 4,4)
    coarsedims = (X(3:6), Y(-4:-1))
    coarse = YAXArray(coarsedims, coarsedata)
    finedims = (X(3:0.5:6), Y(-4:0.5:-1))
    
    # Test with YAXArray
    resampled = xresample(coarse; to=finedims)
    computed = DAE.compute(resampled)
    @test size(computed) == (7, 7)
    @test computed[1] == 1.0
    @test isapprox(computed[1:2:end, 1:2:end][:], coarsedata[:])
    
    # Test with plain DimArray (compute via data field for non-YAXArray)
    coarse_da = DimArray(coarsedata, coarsedims)
    resampled_da = xresample(coarse_da; to=finedims)
    computed_da = DAE.compute(resampled_da.data)
    @test size(computed_da) == (7, 7)
    @test computed_da[1] == 1.0
    
    # Test that output preserves input struct type
    @test typeof(resampled_da) <: DD.AbstractDimArray
    @test DD.name(resampled_da) == DD.name(coarse_da)
    
    # Test partial dimension resampling (only X)
    resampled_partial = xresample(coarse; to=(X(3:0.5:6),))
    computed_partial = DAE.compute(resampled_partial)
    @test size(computed_partial) == (7, 4)
    @test computed_partial[1] == 1.0
end

@testitem "xresample with outspecs" begin
    using YAXArrays
    using DimensionalData
    using DiskArrayEngine: DiskArrayEngine as DAE
    coarsedata = reshape(1:16, 4,4)
    coarsedims = (X(3:6), Y(-4:-1))
    coarse = YAXArray(coarsedims, coarsedata)
    finedims = (X(3:0.5:6), Y(-4:0.5:-1))
    
    # Test with explicit outtype
    resampled = xresample(coarse; to=finedims, outtype=Float64)
    computed = DAE.compute(resampled)
    @test eltype(computed) == Union{Missing, Float64}
    
    # Test with Float32 (default)
    resampled_f32 = xresample(coarse; to=finedims, outtype=Float32)
    computed_f32 = DAE.compute(resampled_f32)
    @test eltype(computed_f32) == Union{Missing, Float32}
end

@testitem "xresample with approxequal dimensions" begin
    using YAXArrays
    using DimensionalData
    coarsedata = reshape(1:16, 4,4, 1)
    coarsedims = (X(range(1.,1.5, length=4)), Y(range(-3.4, -2., length=4)), Ti(2:2))
    coarse = YAXArray(coarsedims, coarsedata)
    finedims = (X(range(1f0,1.5f0, length=4)), Y(range(-3.4f0, -2f0, length=4)))
    interpdata = xresample(coarse, to=finedims)
    @test interpdata.data === coarse.data
    @test dims(interpdata, finedims) == finedims
end
#=
These should be reenabled once we decided what keyword arguments xmap gets. 
    @testset "max cache inputs" begin

        x,y,z = X(1:4), Y(1:5), Z(1:6)
        a1 = YAXArray((x,y,z), rand(4,5,6))
        a2 = YAXArray((x,z,y), rand(4,6,5))
        a3 = YAXArray((x,y), rand(4,5))
        indims = InDims("x")
        outdims = OutDims("x")

        function simple_fun(xout, x1,x2)
            xout .= x1 .+ x2
        end

        # Float64 
        r = xmap(simple_fun, a1 ⊘ :X, a2 ⊘ :X, output=XOutput(:X), max_cache = 6.0e8)
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))

        # MB
        r = mapCube(simple_fun, (a1, a2), indims=(indims, indims), outdims=outdims, max_cache = "0.5MB")
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))

        r = mapCube(simple_fun, (a1, a2), indims=(indims, indims), outdims=outdims, max_cache = "3MB")
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))

        r = mapCube(simple_fun, (a1, a2), indims=(indims, indims), outdims=outdims, max_cache = "10MB")
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))

        # GB
        r = mapCube(simple_fun, (a1, a2), indims=(indims, indims), outdims=outdims, max_cache = "0.1GB")
        @test r.data == a1.data .+ permutedims(a2.data,(1,3,2))
    end

    @testset "Error shown in parallel" begin
        import Zarr
        x,y,z = X(1:4), Y(1:5), Z(1:6)
        a1 = YAXArray((x,y,z), rand(4,5,6))
        indims = InDims("x")
        outdims = OutDims("x")
        @test_throws Exception mapCube((xout, xin) -> xout .= foo(xin), a1; indims, outdims, ispar=false)
        @test_throws CapturedException mapCube((xout, xin) -> xout .= foo(xin), a1; indims, outdims, ispar=true)
    end
=#
