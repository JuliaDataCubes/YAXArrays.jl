using Test

using YAXArrays.YAXTools: PickAxisArray
@testset "PickAxisArray" begin
    p = reshape(1:24, 2, 3, 4)
    a = PickAxisArray(p, [:, true, false, true])
    @test a[1, 5, 1] == p[:, 1, 1]
    @test a[1, 6, 2] == p[:, 1, 2]
    @test a[3, 7, 4] == p[:, 3, 4]

    @test @view(a[1, 5, 1]) == p[:, 1, 1]
    @test @view(a[1, 6, 2]) == p[:, 1, 2]
    @test @view(a[3, 7, 4]) == p[:, 3, 4]

    @test eltype(a) <: Vector{Int}

    a = PickAxisArray(p, [true, false, :, :])
    @test a[1] == p[1, :, :]
    @test view(a, 2) == p[2, :, :]

    @test eltype(a) <: Array{Int,2}

    using OffsetArrays
    p = OffsetArray(reshape(1:48, 4, 3, 4), 0:3, 1:3, 1:4)
    a = PickAxisArray(p, [(1, 1), false, :, :])

    @test a[1, 5] == p[0:2, :, :]
    @test a[2, 6] == p[1:3, :, :]

    @test view(a, 1, 4) == p[0:2, :, :]
    @test view(a, 2, 5) == p[1:3, :, :]

    @test eltype(a) <: Array{Int,3}


    p = OffsetArray(reshape(1:60, 3, 4, 5), 1:3, 0:3, 0:4)
    a = PickAxisArray(p, [false, :, (1, 1), (1, 1)])
    @test a[5, 1, 1] == p[:, 0:2, 0:2]
    @test a[6, 1, 2] == p[:, 0:2, 1:3]
    @test a[6, 2, 3] == p[:, 1:3, 2:4]

    @test view(a, 5, 1, 1) == p[:, 0:2, 0:2]
    @test view(a, 6, 1, 2) == p[:, 0:2, 1:3]
    @test view(a, 6, 2, 3) == p[:, 1:3, 2:4]

    @test eltype(a) <: Array{Int,3}

    p = OffsetArray(reshape(1:60, 3, 4, 5), 1:3, 0:3, 0:4)
    a = PickAxisArray(p, [false, :, (1, 1), (1, 1)], [2, 3, 1])
    @test a[5, 1, 1] == permutedims(p[:, 0:2, 0:2], [2, 3, 1])
    @test a[6, 1, 2] == permutedims(p[:, 0:2, 1:3], [2, 3, 1])
    @test a[6, 2, 3] == permutedims(p[:, 1:3, 2:4], [2, 3, 1])

    @test view(a, 5, 1, 1) == permutedims(p[:, 0:2, 0:2], [2, 3, 1])
    @test view(a, 6, 1, 2) == permutedims(p[:, 0:2, 1:3], [2, 3, 1])
    @test view(a, 6, 2, 3) == permutedims(p[:, 1:3, 2:4], [2, 3, 1])

    @test eltype(a) <: Array{Int,3}
end
