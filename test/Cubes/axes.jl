@testset "Axes" begin

    using Dates
    using YAXArrays.Cubes.Axes:
        axVal2Index, axVal2Index_lb, axVal2Index_ub, findAxis, axname, axsym, renameaxis
    using YAXArrayBase: dimname, dimvals, iscontdim

    axestotest = [
        (CategoricalAxis, "CatAxis", ["One", "Two", "Three"], nothing),
        (RangeAxis, "IntRange", 1:10, 1),
        (RangeAxis, "FloatRange", 1.0:-0.1:0.1, 0.1),
        (
            RangeAxis,
            "MonthTimeRange",
            Date(2001, 1, 1):Month(1):Date(2002, 12, 31),
            Day(30),
        ),
        (
            RangeAxis,
            "DayTimeRange",
            DateTime(2002, 1, 1):Day(1):DateTime(2002, 1, 31),
            Hour(24),
        ),
        (RangeAxis, "Single_IntRange", 1:1, 0),

        #This is currently not used, because we need to design, how this should behave.
        (
            RangeAxis,
            "IrregularTimeAxis",
            [DateTime("2016-10-03T10:12:28"), DateTime("2016-10-15T10:12:28"),
                DateTime("2016-10-27T10:12:28"), DateTime("2016-11-08T10:12:28"),
                DateTime("2016-11-20T10:12:28"), DateTime("2016-12-02T10:12:28"),
                DateTime("2016-12-14T10:12:27"), DateTime("2016-12-26T10:12:27"),
                DateTime("2017-01-07T10:12:25"), DateTime("2017-01-19T10:12:25"),
                DateTime("2017-01-31T10:12:25"), DateTime("2017-02-24T10:12:24")],
            Day(1)
        ),
        (RangeAxis, "PureArray", [0.0, 0.2, 0.4, 0.6], 0.2),
        (CategoricalAxis, "CatAxis", ["One", "Two", "Three", "Four", "Five",
                "Six", "Seven", "Eight", "Nine", "Ten", "Eleven"], nothing),
    ]

    for (axt, axn, axv, axstep) in axestotest
        ax = axt(axn, axv)
        @test size(ax) == size(axv)
        @test size(ax, 1) == size(axv, 1)
        @test ndims(ax) == 1
        @test length(ax) == length(axv)
        ax2 = YAXArrays.Cubes.Axes.axcopy(ax, axv)
        ax3 = YAXArrays.Cubes.Axes.axcopy(ax)
        @test typeof(ax2) == typeof(ax)
        @test ax2.values == ax.values
        @test typeof(ax3) == typeof(ax)
        @test ax3.values == ax.values
        b = IOBuffer()
        show(b, ax)
        @test caxes(ax) == [ax]
        @test YAXArrays.Cubes.Axes.axname(ax) == axn
        @test YAXArrays.Cubes.Axes.axname(typeof(ax)) == axn
        @test YAXArrays.Cubes.axsym(ax) == Symbol(axn)
        @test dimname(ax, 1) == axn
        @test dimvals(ax, 1) == axv
        #Test axVal2Index separately
        if ax isa CategoricalAxis
            for (i, v) in enumerate(axv)
                @test axVal2Index(ax, v) == i
                @test axVal2Index(ax, v[1:2], fuzzy=true) == i
            end
            @test iscontdim(ax, 1) == false
        else
            for (i, v) in enumerate(axv)
                @test axVal2Index(ax, v) == i
                #@test axVal2Index_ub(ax, v + axstep / 2, fuzzy = true) == i
                #@test axVal2Index_lb(ax, v - axstep / 2, fuzzy = true) == i
            end
            @test iscontdim(ax, 1) == true
        end
        ax3 = renameaxis(ax, "Test")
        ax4 = renameaxis(ax, :Test)
        @test axname(ax3) == "Test"
        @test axsym(ax3) == :Test

        # test getindex method
        for i in eachindex(axv)
            @test ax[i] == axv[i]
        end
    end
    axlist = map(i -> i[1](i[2], i[3]), axestotest)
    @test findAxis("Int", axlist) == 2
    @test findAxis(RangeAxis("FloatRange", 1.0:-0.1:0.1), axlist) == 3
    @test getAxis(RangeAxis("FloatRange", 1.0:-0.1:0.1), axlist) ==
          RangeAxis("FloatRange", 1.0:-0.1:0.1)
    #Test whether multiple axes with same name throw an error
    @test_throws ErrorException findAxis("CatAxis", axlist)

    multiplevalax = CategoricalAxis("MultVal", ["One", "Two", "One"])
    @test_throws ErrorException axVal2Index(multiplevalax, "one", fuzzy=true)
    @testset "Hashtests" begin
        catax = CategoricalAxis("Catax", [1, 2])
        catay = CategoricalAxis("Catay", [1, 2])
        catax2 = CategoricalAxis("Catax", [2, 2])
        cataxfloat = CategoricalAxis("Catax", [1.0, 2.0])
        @test hash(catax) == hash(cataxfloat)
        @test hash(catax) != hash(catay)
        @test hash(catax) != hash(catax2)
    end

end
