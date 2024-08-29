@testset "Transformed cubes" begin
    @testset "Simple map" begin
        data = collect(reshape(1:20, 4, 5))
        axlist = (X(1.0:4.0), Y([1, 2, 3, 4, 5]))
        props = Dict("att1" => 5, "att2" => "Hallo")
        a = YAXArray(axlist, data, props)
        a2 = map(i -> i + 1, a)
        @test all(a2.data .== a.data .+ 1)
        @test a2.axes == a.axes
        @test a2.properties == a.properties
        #TODO: Test that cleaners get promoted properly
        a3 = map(+, a, a2)
        @test all(a3.data .== a.data .+ a2.data)
        @test a3.axes == a.axes
        @test a3.properties == a.properties
    end
    @testset "Cube concatenation" begin
        data = [rand(4, 5) for i = 1:3]
        axlist = (X(1.0:4.0), Y([1, 2, 3, 4, 5]))
        props = [Dict("att$i" => i) for i = 1:3]
        singlecubes = [YAXArray(axlist, data[i], props[i]) for i = 1:3]
        newcube = concatenatecubes(singlecubes, Z(["A", "B", "C"]))
        @test caxes(newcube) == (X(1.0:4.0), Y([1, 2, 3, 4, 5]), Z(["A", "B", "C"]))
        @test ndims(newcube) == 3
        @test size(newcube) == (4, 5, 3)
        @test newcube[:, :, :] == cat(data..., dims=3)
        @test getattributes(newcube) == reduce(merge, props)
    end
    @testset "ConcatDiskArray" begin
        using Zarr
        lon_range = X(-180:180)
        lat_range = Y(-90:90)
        data = [exp(cosd(lon)) + 3 * (lat / 90) for lon in lon_range, lat in lat_range]
        a = YAXArray((lon_range, lat_range), data)
        ds_ram = Dataset(; properties=Dict(), a)
        path = tempname()
        savedataset(ds_ram; path=path)
        ds_disk = open_dataset(path)
        a_ram = cat(ds_ram.a[X=1:100], ds_ram.a[X=101:200], dims=:X)
        a_disk = cat(ds_disk.a[X=1:100], ds_disk.a[X=101:200], dims=:X)

        @test collect(x for x in a_disk) == collect(x for x in a_ram)

        rm(path, recursive=true)
    end
end
