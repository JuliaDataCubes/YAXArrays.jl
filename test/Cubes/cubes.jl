using YAXArrays, YAXArrayBase, Test, Dates
using DimensionalData

@testset "YAXArrays" begin
    data = collect(reshape(1:20, 4, 5))
    axlist = (X(1.0:4.0), Dim{:YVals}([1, 2, 3, 4, 5]))
    props = Dict("att1" => 5, "att2" => "Hallo")
    a = YAXArray(axlist, data, props)

    @testset "Array construction sanity checks" begin
        @test_throws ArgumentError YAXArray(axlist[1:1], data, props)
        @test_throws ArgumentError YAXArray(
            (X(1.0:4.0), Dim{:YVals}([1, 2, 3, 4])),
            data,
            props,
        )
    end

    @testset "Basic array Functions" begin
        @test size(a) == (4, 5)
        @test size(a, 1) == 4     
        @test size(a, :X) == 4
        @test size(a, 2) == 5
        @test size(a, :YVals) == 5
        @test eltype(a) == Int
        @test ndims(a) == 2
        @test a.X == axlist[1]
        @test a.YVals == axlist[2]
        pa = permutedims(a, (2, 1))
        @test pa.axes == axlist[[2, 1]]
        @test pa.data == transpose(data)
        @test pa.X == axlist[1]
        @test pa.YVals == axlist[2]
        @test a[2, 3] == a.data[2, 3]
        @test parent(a) isa Array
        @test parent(a) == collect(reshape(1:20, 4, 5))
        @test propertynames(a) == (:X, :YVals, :axes, :data)
        @test propertynames(a, true) == (:X, :YVals, :axes, :data, :properties)
    end

    @testset "YAXArray interface functions" begin

        a2 = readcubedata(a)
        @test a2.axes == a.axes
        @test a.data == a2.data
        #@test a2.data isa Array

        @test caxes(a) == axlist

        @test YAXArrays.Cubes.cubechunks(a) == (4, 5)

        cs = CartesianIndices.(collect(Iterators.product([1:2, 3:5, 6:6], [1:2, 3:4])))

        a2  = renameaxis!(a2, :X => :Ax1)

        @test YAXArrayBase.dimname(a2, 1) == :Ax1

        a2 = renameaxis!(a2, :Ax1 => X(2:5))

        @test lookup(a2.axes[1]) == 2:5

        b = IOBuffer()
        show(b, a)
        # @test String(take!(b))=="""
        # YAXArray with the following dimensions
        # XVals               Axis with 4 Elements from 1.0 to 4.0
        # YVals               Axis with 5 elements: 1 2 3 4 5
        # Total size: 160.0 bytes
        # """
    end

    @testset "YAXArrayBase interface" begin
        using YAXArrayBase
        @test YAXArrayBase.dimvals(a, 1) == 1.0:4.0
        @test YAXArrayBase.dimvals(a, 2) == [1, 2, 3, 4, 5]
        @test YAXArrayBase.dimname(a, 1) == :X
        @test YAXArrayBase.dimname(a, 2) == :YVals
        @test YAXArrayBase.getattributes(a) == Dict("att1" => 5, "att2" => "Hallo")
        #@test YAXArrayBase.iscontdim(a, 1) == true
        #@test YAXArrayBase.iscontdim(a, 2) == false # We need to decide what to do with iscontdim
        @test YAXArrayBase.getdata(a) === data
        a2 = YAXArrayBase.yaxcreate(
            YAXArray,
            reshape(1:27, 3, 3, 3),
            [:d1, :d2, :d3],
            [1:3, ["One", "Two", "Three"], 0.1:0.1:0.3],
            Dict("att" => 5),
        )
        @test a2 isa YAXArray
        @test a2.axes[1] == Dim{:d1}(1:3)
        @test a2.axes[2] == Dim{:d2}(["One", "Two", "Three"])
        @test a2.axes[3] == Dim{:d3}(0.1:0.1:0.3)
        @test a2.data == reshape(1:27, 3, 3, 3)
        @test a2.properties == Dict("att" => 5)
        @test YAXArrayBase.iscompressed(a) == false
    end

    @testset "cubesize" begin
        @test Cubes.cubesize(a) == 160
        a32 = map(Float32, a)
        @test Cubes.cubesize(a32) == 80

        @test endswith(Cubes.formatbytes(160), "bytes")
        @test endswith(Cubes.formatbytes(1205), "KB")
        @test endswith(Cubes.formatbytes(1200000), "MB")
    end
#=
    @testset "Subsets" begin
        s = YAXArrays.Cubes.subsetcube(a, X = 1.5..3.5)
        @test s.data == [2 6 10 14 18; 3 7 11 15 19]
        @test s.axes[1] == X(2.0:3.0)
        @test s.axes[2] == Y([1, 2, 3, 4, 5])
        ax = a.axes[1]
        @test YAXArrays.Cubes.interpretsubset(CartesianIndices((1:2,)), ax) == 1:2
        @test YAXArrays.Cubes.interpretsubset(CartesianIndex((2,)), ax) == 2
        @test YAXArrays.Cubes.interpretsubset(2.1, ax) == 2
        @test YAXArrays.Cubes.interpretsubset((3.5, 1.5), ax) == 2:3
        @test YAXArrays.Cubes.interpretsubset(0.8..2.2, ax) == 1:2
        tax = RangeAxis("ADate", Date(2001):Day(1):Date(2003, 2, 28))
        @test YAXArrays.Cubes.interpretsubset((Date(2001, 1, 2), Date(2001, 1, 5)), tax) ==
              2:4
        @test YAXArrays.Cubes.interpretsubset(2001:2002, tax) == 1:730
        @test YAXArrays.Cubes.interpretsubset([1, 3, 5], a.axes[2]) == [1, 3, 5]

        s2 = a[X = 0.5..3.5, Y = [1, 5, 4]]
        @test s2.data == [1 17 13; 2 18 14; 3 19 15]
        @test s2.axes[1] == X(1.0:3.0)
        @test s2.axes[2] == Y([1, 5, 4])
    end
=#
end
