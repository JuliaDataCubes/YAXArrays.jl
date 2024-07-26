using DataStructures: OrderedDict
using DimensionalData
using DimensionalData: DimensionalData as DD
using Dates


@testset "Datasets axes Ti" begin
    using Zarr, NetCDF

    ## first example
    data = [rand(4, 5, 12), rand(4, 5, 12), rand(4, 5)]
    # dim_time = DD.Dim{:Time}(Date(2001, 1, 15):Month(1):Date(2001, 12, 15))
    dim_time = Ti(Date(2001, 1, 15):Month(1):Date(2001, 12, 15))
    axlist1 = (
        DD.Dim{:XVals}(1.0:4.0),
        DD.Dim{:YVals}([1, 2, 3, 4, 5]),
        dim_time
    )
    axlist2 = (DD.Dim{:XVals}(1.0:4.0), DD.Dim{:YVals}([1, 2, 3, 4, 5]))
    props = [Dict("att$i" => i) for i = 1:3]
    c1, c2, c3 = (
        YAXArray(axlist1, data[1], props[1]),
        YAXArray(axlist1, data[2], props[2]),
        YAXArray(axlist2, data[3], props[3]),
    )
    ds = Dataset(avar=c1, something=c2, smaller=c3)
    # previous version will throw this error: `KeyError: key :Ti not found`
    f = "./temp.zarr"
    @test_nowarn savedataset(ds; path=f)
    rm(f, recursive=true, force=true)


    ## second example
    using Downloads
    path2file = "https://www.unidata.ucar.edu/software/netcdf/examples/sresa1b_ncar_ccsm3-example.nc"
    filename = Downloads.download(path2file, "sresa1b_ncar_ccsm3-example.nc")
    ds = open_dataset(filename)
    f = "./temp.zarr"
    savedataset(ds, path=f, driver=:zarr, overwrite=true)
    rm(f, recursive=true, force=true)
    rm(filename)

    ## third example
    # using EarthDataLab
    # using DimensionalData
    # using Zarr, YAXArrays, ra = esdc(res="tiny")
    # ra_tair = ra[variable=At("air_temperature_2m")]
    # ra_resp = ra[variable=At("terrestrial_ecosystem_respiration")]
    # ds = Dataset(tair=ra_tair, resp=ra_resp)
    # f = "./temp.zarr"
    # savedataset(ds, path=f, driver=:zarr, overwrite=true)
    # rm(f, recursive=true, force=true)
end


@testset "Datasets" begin
    data = [rand(4, 5, 12), rand(4, 5, 12), rand(4, 5)]
    axlist1 = (
        DD.Dim{:XVals}(1.0:4.0),
        DD.Dim{:YVals}([1, 2, 3, 4, 5]),
        DD.Dim{:Time}(Date(2001, 1, 15):Month(1):Date(2001, 12, 15)),
    )
    axlist2 = (DD.Dim{:XVals}(1.0:4.0), DD.Dim{:YVals}([1, 2, 3, 4, 5]))
    props = [Dict("att$i" => i) for i = 1:3]
    c1, c2, c3 = (
        YAXArray(axlist1, data[1], props[1]),
        YAXArray(axlist1, data[2], props[2]),
        YAXArray(axlist2, data[3], props[3]),
    )
    ds = Dataset(avar=c1, something=c2, smaller=c3)
    @testset "Basic functions" begin
        b = IOBuffer()
        show(b, ds)
        s = split(String(take!(b)), "\n")
        s2 = """
        YAXArray Dataset
        Shared Axes:
        XVals               Axis with 4 Elements from 1.0 to 4.0
        YVals               Axis with 5 elements: 1 2 3 4 5
        Variables: 
        """
        s2 = split(s2, "\n")
        @test s[[1]] == s2[[1]]
        #     @test all(i->in(i,s2), s[3:5])
        for n in [:avar, :something, :smaller, :XVals, :Time, :YVals]
            @test n in propertynames(ds)
            @test n in propertynames(ds, true)
        end
        @test :axes ∉ propertynames(ds)
        @test :cubes ∉ propertynames(ds)
        @test :axes ∈ propertynames(ds, true)
        # Test getproperty
        @test all(i -> in(i, values(ds.axes)), axlist1)
        @test collect(keys(ds.cubes)) == [:avar, :something, :smaller]
        @test collect(values(ds.cubes)) == [c1, c2, c3]
        @test ds.avar === c1
        @test ds.something === c2
        @test ds.smaller === c3
        @test ds[:avar] === c1
        ds2 = ds[[:avar, :smaller]]
        @test collect(keys(ds2.cubes)) == [:avar, :smaller]
        @test collect(values(ds2.cubes)) == [c1, c3]
        @test YAXArrays.Datasets.fuzzyfind("hal", ["hallo", "bla", "something"]) == 1
        ds3 = ds[["av", "some"]]
        @test collect(keys(ds3.cubes)) == [:av, :some]
        @test collect(values(ds3.cubes)) == [c1, c2]
        @test ds["avar"] === c1
        #@test length(ds3[Time=(Date(2001,2,1),Date(2001,8,1))].Time) == 6 
    end
    @testset "Subsetting datasets" begin
        dssub = ds[Time=DD.At(Date(2001, 2, 15))]
        @test dssub isa Dataset
        @test sort(collect(keys(dssub.axes))) == [:XVals, :YVals]
        @test ndims(dssub.avar) == 2
        dssub2 = ds[var=[:avar, :something], Time=Date(2001, 1, 15) .. Date(2001, 6, 15)]
        @test length(dssub2.cubes) == 2
        @test size(dssub2.avar) == (4, 5, 6)
    end
    @testset "Dataset interface" begin
        struct MockDataset
            vars::Any
            dims::Any
            gattrs::Any
            attrs::Any
            path::Any
        end
        Base.getindex(d::MockDataset, i) = d.vars[i]
        Base.haskey(d::MockDataset, i) = haskey(d.vars, i)
        YAXArrayBase.get_varnames(d::MockDataset) = (keys(d.vars)...,)
        YAXArrayBase.get_var_dims(d::MockDataset, name) = d.dims[name]
        YAXArrayBase.get_var_attrs(d::MockDataset, name) = d.attrs[name]
        YAXArrayBase.get_global_attrs(d::MockDataset) = d.gattrs
        YAXArrayBase.allow_missings(d::MockDataset) = !occursin("nomissings", d.path)
        function YAXArrayBase.create_empty(::Type{MockDataset}, path, gatts)
            mkpath(dirname(path))
            open(_ -> nothing, path, "w")
            MockDataset(Dict(), Dict(), gatts, Dict(), path)
        end
        function YAXArrayBase.add_var(ds::MockDataset, T, name, s, dimlist, atts; kwargs...)
            data = Array{T}(undef, s...)
            ds.vars[name] = data
            ds.dims[name] = dimlist
            ds.attrs[name] = atts
            data
        end
        YAXArrayBase.backendlist[:mock] = MockDataset
        push!(YAXArrayBase.backendregex, r".mock$" => MockDataset)
        data1, data2, data3, d1, d2, d3 =
            (rand(12, 5, 2), rand(12, 5), rand(12, 5, 2), 1:12, 0.1:0.1:0.5, ["One", "Two"])
        att1 = Dict("att1" => 5, "_ARRAY_OFFSET" => (2, 0, 0))
        att2 = Dict("att2" => 6, "_ARRAY_OFFSET" => (2, 0))
        attd1 = Dict(
            "_ARRAY_OFFSET" => 2,
            "units" => "days since 2001-01-01",
            "calendar" => "gregorian",
        )
        attd2 = Dict("attd" => "d")
        attd3 = Dict("attd" => "d")
        function MockDataset(p)
            MockDataset(
                OrderedDict(
                    "Var1" => data1,
                    "Var2" => data2,
                    "Var3" => data3,
                    "time" => d1,
                    "d2" => d2,
                    "d3" => d3,
                ),
                Dict(
                    "Var1" => ("time", "d2", "d3"),
                    "Var2" => ("time", "d2"),
                    "Var3" => ("time", "d2", "d3"),
                    "time" => ("time",),
                    "d2" => ["d2"],
                    "d3" => ["d3"],
                ),
                Dict(
                    "global_att1" => 5,
                    "global_att2" => "Hi",
                ),
                Dict(
                    "Var1" => att1,
                    "Var2" => att2,
                    "Var3" => att1,
                    "time" => attd1,
                    "d2" => attd2,
                    "d3" => attd3,
                ),
                p,
            )
        end
        m = MockDataset("testpath.mock")
        @testset "collectdims" begin
            dcollect = YAXArrays.Datasets.collectdims(m)
            @test dcollect["time"].ax isa DD.Dimension
            #@test YAXArrays.Cubes.Axes.axname(dcollect["time"].ax) == "time"
            @test DD.lookup(dcollect["time"].ax) ==
                  DateTime(2001, 1, 4):Day(1):DateTime(2001, 1, 13)
            @test dcollect["time"].offs == 2
            @test dcollect["d2"].ax isa DD.Dimension
            #@test YAXArrays.Cubes.Axes.axname(dcollect["d2"].ax) == "d2"
            @test DD.lookup(dcollect["d2"].ax) == 0.1:0.1:0.5
            @test dcollect["d2"].offs == 0
            @test dcollect["d3"].ax isa DD.Dimension
            #@test YAXArrays.Cubes.Axes.axname(dcollect["d3"].ax) == "d3"
            @test DD.lookup(dcollect["d3"].ax) == ["One", "Two"]
            @test dcollect["d3"].offs == 0
            a1 = [0.1, 0.2, 0.3, 0.4]
            a2 = [0.1, 0.21, 0.3, 0.4]
            @test YAXArrays.Datasets.testrange(a1) == 0.1:0.1:0.4
            @test YAXArrays.Datasets.testrange(a2) isa Array
            @test YAXArrays.Datasets.testrange(a2) == [0.1, 0.21, 0.3, 0.4]
        end
        @testset "open_dataset" begin
            ds = open_dataset("test.mock")
            @test size(ds.Var1) == (10, 5, 2)
            @test size(ds.Var2) == (10, 5)
            @test all(in(keys(ds.axes)), (:Ti, :d2, :d3))
            ar = Cube(ds)
            @test ar isa YAXArray
            @test size(ar) == (10, 5, 2, 2)
            @test DD.name.(ar.axes) == (:Ti, :d2, :d3, :Variable)
            @test DD.lookup(ar.axes[4]) == ["Var1", "Var3"]
        end
        @testset "Dataset creation" begin
            al = (
                DD.Dim{:Time}(Date(2001):Month(1):Date(2001, 12, 31)),
                DD.Dim{:Variable}(["A", "B"]),
                DD.Dim{:Xvals}(1:10),
            )
            # Basic
            newds, newds2 = YAXArrays.Datasets.createdataset(MockDataset, al)
            @test DD.name.(newds2.axes) == (:Time, :Xvals, :Variable)
            @test DD.lookup(newds2.axes[1]) == Date(2001):Month(1):Date(2001, 12, 31)
            @test DD.lookup(newds2.axes[3]) == ["A", "B"]
            @test DD.lookup(newds2.axes[2]) == 1:10
            @test newds2.data isa YAXArrays.Cubes.DiskArrayTools.DiskArrayStack
            # A bit more advanced
            fn = string(tempname(), ".mock")
            newds, newds2 = YAXArrays.Datasets.createdataset(
                MockDataset,
                al,
                path=fn,
                persist=false,
                chunksize=(4, 2, 4),
                chunkoffset=(2, 0, 3),
                properties=Dict("att1" => 5),
                datasetaxis="A",
            )
            @test size(newds.data) == (12, 2, 10)
            @test size(newds.data.a.parent) == (14, 2, 13)
            @test eltype(newds.data) <: Union{Float32,Missing}
            @test newds.properties["att1"] == 5
            @test isfile(fn)
            newds = nothing
            newds2 = nothing
            # Without missings
            fn = string(tempname(), "nomissings.mock")
            newds = YAXArrays.Datasets.createdataset(
                MockDataset,
                al,
                path=fn,
                datasetaxis="A",
            )
        end
    end
end

@testset "Saving and loading between different backends" begin
    using NetCDF, Zarr, YAXArrays
    x = rand(10, 5)
    ax1 = Dim{:Ax1}(string.(1:10))
    ax2 = Dim{:Ax2}(1:5)
    p = string(tempname(), ".zarr")
    savecube(YAXArray((ax1, ax2), x), p, backend=:zarr)
    @test ispath(p)
    cube1 = Cube(p)
    @test cube1.Ax1 == ax1
    @test cube1.Ax2 == ax2
    @test eltype(cube1.Ax2) <: Int64
    @test cube1.data == x
    p2 = string(tempname(), ".nc")
    savecube(cube1, p2, backend=:netcdf)
    @test ispath(p2)
    cube2 = Cube(p2)
    @test cube2.Ax1 == ax1
    @test cube2.Ax2 == ax2
    @test cube2.data == x
    @test eltype(cube2.Ax2) <: Int64
end

@testset "Saving, loading and appending" begin
    using YAXArrays, Zarr, NetCDF, DiskArrays
    x, y, z = rand(10, 20), rand(10), rand(10, 20, 5)
    a, b, c = YAXArray.((x, y, z))
    f = tempname() * ".zarr"
    savecube(a, f, backend=:zarr)
    cube = Cube(f)
    @test cube.axes == a.axes
    @test cube.data == x
    @test cube.chunks == a.chunks

    f = tempname() * ".nc"
    savecube(a, f, backend=:netcdf)
    cube = Cube(f)
    @test cube.axes == a.axes
    @test cube.data == x
    @test cube.chunks == a.chunks

    ds = Dataset(; a, b)
    f = tempname()
    savedataset(ds, path=f, driver=:zarr)
    ds = open_dataset(f, driver=:zarr)
    @test ds.a.axes == a.axes
    @test ds.a.data == x
    @test ds.a.chunks == a.chunks

    @test ds.b.axes == b.axes
    @test ds.b.data == y
    @test ds.b.chunks == b.chunks

    ds2 = Dataset(c=c)
    savedataset(ds2, path=f, backend=:zarr, append=true)
    ds = open_dataset(f, driver=:zarr)

    @test ds.a.axes == a.axes
    @test ds.a.data == x
    @test ds.a.chunks == a.chunks

    @test ds.b.axes == b.axes
    @test ds.b.data == y
    @test ds.b.chunks == b.chunks

    @test ds.c.axes == c.axes
    @test ds.c.data[:, :, :] == z
    @test ds.c.chunks == c.chunks


    d = YAXArray(zeros(Union{Missing,Int32}, 10, 20))
    f = tempname()
    r = savecube(d, f, driver=:zarr, skeleton=true)
    @test all(ismissing, r[:, :])

    d = YAXArray(zeros(Int32, 10, 20))
    f = tempname()
    r = savecube(d, f, driver=:zarr, skeleton=true)
    @test all(==(YAXArrayBase.defaultfillval(Int32)), r[:, :])


    f = tempname() * ".zarr"
    a_chunked = setchunks(a, (5, 10))
    savecube(a_chunked, f, backend=:zarr)
    @test Cube(f).chunks == DiskArrays.GridChunks(size(a), (5, 10))


    ds = Dataset(; a, b, c)
    dschunked = setchunks(ds, Dict("Dim_1" => 5, "Dim_2" => 10, "Dim_3" => 2))
    f = tempname()
    savedataset(dschunked, path=f, driver=:zarr)
    ds = open_dataset(f, driver=:zarr)
    @test ds.a.axes == a.axes
    @test ds.a.data[:, :] == x
    @test ds.a.chunks == DiskArrays.GridChunks(size(a), (5, 10))

    @test ds.b.axes == b.axes
    @test ds.b.data[:] == y
    @test ds.b.chunks == DiskArrays.GridChunks(size(b), (5,))

    @test ds.c.axes == c.axes
    @test ds.c.data[:, :, :] == z
    @test ds.c.chunks == DiskArrays.GridChunks(size(c), (5, 10, 2))


    ds = Dataset(; a, b, c)
    dschunked = setchunks(ds, (a=(5, 10), b=Dict("Dim_1" => 5), c=(Dim_1=5, Dim_2=10, Dim_3=2)))
    f = tempname()
    savedataset(dschunked, path=f, driver=:zarr)
    ds = open_dataset(f, driver=:zarr)

    @test ds.a.axes == a.axes
    @test ds.a.data[:, :] == x
    @test ds.a.chunks == DiskArrays.GridChunks(size(a), (5, 10))

    @test ds.b.axes == b.axes
    @test ds.b.data[:] == y
    @test ds.b.chunks == DiskArrays.GridChunks(size(b), (5,))

    @test ds.c.axes == c.axes
    @test ds.c.data[:, :, :] == z
    @test ds.c.chunks == DiskArrays.GridChunks(size(c), (5, 10, 2))


    ds = Dataset(a=YAXArray(rand(10, 20)), b=YAXArray(rand(10, 20)), c=YAXArray(rand(10, 20)))
    dschunked = setchunks(ds, (5, 10))
    f = tempname()
    savedataset(dschunked, path=f, driver=:zarr)
    ds2 = open_dataset(f, driver=:zarr)

    @test ds2.a.axes == ds.a.axes
    @test ds2.a.data[:, :] == ds.a.data
    @test ds2.a.chunks == DiskArrays.GridChunks(size(a), (5, 10))

    @test ds2.b.axes == ds.b.axes
    @test ds2.b.data[:, :] == ds.b.data
    @test ds2.b.chunks == DiskArrays.GridChunks(size(a), (5, 10))

    @test ds2.c.axes == ds.c.axes
    @test ds2.c.data[:, :] == ds.c.data
    @test ds2.c.chunks == DiskArrays.GridChunks(size(a), (5, 10))

end

@testset "Caching" begin
    using YAXArrays.Cubes.DiskArrays.TestTypes
    using YAXArrays.Cubes: DiskArrays
    using Test
    import DimensionalData as DD
    a = AccessCountDiskArray(reshape(1:100, 5, 20), chunksize=(2, 10))
    ds = Dataset(; ar=YAXArray((DD.X(1:5), DD.Y(1:20)), a))
    dscached = DiskArrays.cache(ds)
    @test isa(dscached.ar.data, DiskArrays.CachedDiskArray)
    @test dscached.ar[1, 1] == 1
    @test dscached.ar[2, 1:10] == 2:5:47
    @test getindex_count(a) == 1
    dssub = dscached[X=DD.Between(3, 5), Y=DD.Between(19, 20)]
    @test dssub.ar[:, :].data == [93 98; 94 99; 95 100]
    @test getindex_count(a) == 3
    @test length(dscached.ar.data.cache) == 3
end

@testset "Mapslices" begin
    using YAXArrays, StatsBase

    a = ones(10, 20, 5)
    cube = YAXArray(a)
    mean_slice = mapslices(mean, cube; dims="Dim_1")

    @test mean_slice[:, :] == ones(20, 5)
end

@testset "Making Cubes from heterogemous data types" begin
    a1 = YAXArray(rand(Int8, 10, 10))
    a2 = YAXArray(rand(Float32, 10, 10))
    a3 = YAXArray(rand(Int16, 10, 10))
    a4 = YAXArray(rand(Float64, 10, 10))
    a5 = YAXArray(fill("hello", 10, 10))
    ds = Dataset(a=a1, b=a2, c=a3, d=a4)

    c = Cube(ds)
    @test size(c) == (10, 10, 4)
    @test eltype(c) <: Float64
    x = c[var=At("c")][:, :]
    @test eltype(x) <: Float64
    @test x == Float64.(a3.data)

    ds = Dataset(a=a1, b=a2, c=a3, d=a4, e=a5)
    @test_throws ArgumentError Cube(ds)
end
