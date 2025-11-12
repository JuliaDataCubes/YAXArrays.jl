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

    # Scalar broadcasting
    x1 = a .+ 1
    @test eltype(x1) == eltype(a)
    @test size(x1) == size(a)
    @test all(x1[:] .== 2.0)

    x2 = 1 .+ a
    @test all(x2[:] .== 2.0)

    # Element-wise addition
    xadd = a .+ b
    @test all(xadd[:] .== 1.0)

    # Element-wise multiplication
    xmul = a .* b
    @test all(xmul[:] .== 0.0)

    # Unary functions
    xneg = -a
    @test all(xneg[:] .== -1.0)

    xabs = abs.(xneg)
    @test all(xabs[:] .== 1.0)

    # Logical / predicates
    xisnan = isnan.(c)
    @test eltype(xisnan) == Bool
    @test xisnan[1,2] == true
    @test xisnan[2,3] == true
    @test xisnan[1,1] == false

    xnotnan = .!isnan.(c)
    @test xnotnan[1,1] == true
    @test xnotnan[1,2] == false

    # Mixed operations
    xmix = (a .+ b) .* 2 .- 1
    @test all(xmix[:] .== 1.0)

    # Chained broadcasts
    xchain = .!isnan.(c .+ 1)
    @test xchain[1,2] == false
    @test xchain[1,1] == true

    # Mixed operations with numbers
    xscalar = a .* 3 .+ 1
    @test all(xscalar[:] .== 4.0)
    @test isa(a .+ b, YAXArray)
end

@testset "missing handling" begin
    am = YAXArray([missing 1 ; 1 2])
    aeq = am .== am
    @test eltype(aeq) == Union{Missing, Bool}
    @test ismissing(aeq[1,1])
    @test aeq[1,2]
    aeq2 = similar(aeq)
    aeq2 .= am .== am
    @test eltype(aeq2) == Union{Missing, Bool}
    @test ismissing(aeq2[1,1])
    @test aeq2[2,2]
end