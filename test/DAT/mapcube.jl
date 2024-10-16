@testitem "mapcube" begin
    using YAXArrays
    using DimensionalData
    @testset "Loop Axis permutation" begin
        x,y,z = X(1:4), Y(1:5), Z(1:6)
        a1 = YAXArray((x,y,z), rand(4,5,6))
        a2 = YAXArray((x,z,y), rand(4,6,5))
        a3 = YAXArray((x,y), rand(4,5))
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
        r = mapCube((a2, a3), indims=(indims, indims), outdims=outdims,nthreads = [1]) do xout, x1, x2
            xout .= x1 .+ x2
        end
        @test r.data == a2.data .+ reshape(a3.data,(4,1,5))
    end

    @testset "Reduction to empty outputs" begin
        yax = YAXArray((Dim{:axis1}(1:10),), rand(10))
        r = mapslices(sum, yax, dims="axis1")
        @test r.data[] == sum(yax.data)

    end

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
        r = mapCube(simple_fun, (a1, a2), indims=(indims, indims), outdims=outdims, max_cache = 6.0e8)
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
        x,y,z = X(1:4), Y(1:5), Z(1:6)
        a1 = YAXArray((x,y,z), rand(4,5,6))
        indims = InDims("x")
        outdims = OutDims("x")
        @test_throws Exception mapCube((xout, xin) -> xout .= foo(xin), a1; indims, outdims, ispar=false)
        @test_throws CapturedException mapCube((xout, xin) -> xout .= foo(xin), a1; indims, outdims, ispar=true)
        
    end
end