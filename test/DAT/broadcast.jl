using Test
using YAXArrays

function sample_arrays()
    a = YAXArray(ones(3,4))
    b = YAXArray(zeros(3,4))
    c = YAXArray([1.0  NaN 3.0; 4.0 5.0 NaN])
    return a, b, c
end

a, b, c = sample_arrays()

@testset "YAXArray lazy broadcast tests" begin
    for lazy in (true, false)
        YAXArrays.Xmap.LAZY_INMEMORY_XMAP[] = lazy
        # Scalar broadcasting
        x1 = a .+ 1
        @test eltype(x1) == eltype(a)
        @test size(x1) == size(a)
        @test all(x1[:] .== 2.0)
        @test DiskArrays.isdisk(x1) == lazy
        x2 = 1 .+ a
        @test all(x2[:] .== 2.0)
        @test DiskArrays.isdisk(x2) == lazy

        # Element-wise addition
        xadd = a .+ b
        @test all(xadd[:] .== 1.0)
        @test DiskArrays.isdisk(xadd) == lazy

        # Element-wise multiplication
        xmul = a .* b
        @test all(xmul[:] .== 0.0)
        @test DiskArrays.isdisk(xmul) == lazy
        # Unary functions
        xneg = -a
        @test all(xneg[:] .== -1.0)
        @test DiskArrays.isdisk(xneg) == lazy
        xabs = abs.(xneg)
        @test all(xabs[:] .== 1.0)
        @test DiskArrays.isdisk(xabs) == lazy
        # Logical / predicates
        xisnan = isnan.(c)
        @test eltype(xisnan) == Bool
        @test xisnan[1,2] == true
        @test xisnan[2,3] == true
        @test xisnan[1,1] == false                
        @test DiskArrays.isdisk(xisnan) == lazy

        xnotnan = .!isnan.(c)
        @test xnotnan[1,1] == true
        @test xnotnan[1,2] == false
        @test DiskArrays.isdisk(xnotnan) == lazy

        # Mixed operations
        xmix = (a .+ b) .* 2 .- 1
        @test all(xmix[:] .== 1.0)

        # Chained broadcasts
        xchain = .!isnan.(c .+ 1)
        @test xchain[1,2] == false
        @test xchain[1,1] == true
        @test DiskArrays.isdisk(xchain) == lazy
        # Mixed operations with numbers
        xscalar = a .* 3 .+ 1
        @test all(xscalar[:] .== 4.0)
        @test DiskArrays.isdisk(xscalar) == lazy
        @test isa(a .+ b, YAXArray)

    end
end