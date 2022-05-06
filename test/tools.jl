
@testset "@loadOrGenerate" begin
    using YAXArrayBase
    using Zarr

    data_a = collect(reshape(rand(20), 4, 5))
    axlist = [RangeAxis("XVals", 1.0:4.0), CategoricalAxis("YVals", [1, 2, 3, 4, 5])]
    props = Dict("att1" => 5, "att2" => "Hallo")

    @loadOrGenerate a => "a.zarr" begin
        a = YAXArray(axlist, data_a, props)
    end

    @test isdir("a.zarr")

    data_a2 = collect(reshape(rand(20), 4, 5))
    @loadOrGenerate a2 => "a.zarr" begin
        a2 = YAXArray(axlist, data_a2, props)
    end

    @test all(a.data .=== a2[:, :])

    data_b = collect(reshape(rand(20), 4, 5))
    data_c = collect(reshape(rand(20), 4, 5))
    @loadOrGenerate b => "b.zarr" c => "c.zarr" begin
        b = YAXArray(axlist, data_b, props)
        c = YAXArray(axlist, data_c, props)
    end

    data_b2 = collect(reshape(rand(20), 4, 5))
    data_c2 = collect(reshape(rand(20), 4, 5))
    @loadOrGenerate b2 => "b.zarr" c2 => "c.zarr" begin
        b2 = YAXArray(axlist, data_b2, props)
        c2 = YAXArray(axlist, data_c2, props)
    end

    @test all(b.data .=== b2[:, :])
    @test all(c.data .=== c2[:, :])

    d_dir = "d.zarr"
    data_d = collect(reshape(rand(20), 4, 5))
    @loadOrGenerate d => d_dir begin
        d = YAXArray(axlist, data_d, props)
    end

    @test isdir(d_dir)

    data_d2 = collect(reshape(rand(20), 4, 5))
    @loadOrGenerate d2 => d_dir begin
        d2 = YAXArray(axlist, data_d2, props)
    end

    @test all(d.data .=== d2[:, :])

    rm("a.zarr", recursive = true)
    rm("b.zarr", recursive = true)
    rm("c.zarr", recursive = true)
    rm("d.zarr", recursive = true)
end
