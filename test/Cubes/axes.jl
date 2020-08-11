using YAXArrays, Test, Dates

@testset "Axes" begin

using YAXArrays.Cubes.Axes: axVal2Index

axestotest =
  [ (CategoricalAxis, "CatAxis",["One", "Two", "Three"]),
    (RangeAxis, "IntRange",1:10),
    (RangeAxis, "FloatRange",0.1:0.1:1.0),
    (RangeAxis, "MonthTimeRange",Date(2001,1,1):Month(1):Date(2002,12,31)), 
    (RangeAxis, "DayTimeRange",Date(2002,1,1):Day(1):Date(2002,1,31)),
    (RangeAxis, "PureArray", [0.0,0.2,0.4,0.6])
]
for (axt, axn, axv) in axestotest
    ax = axt(axn, axv)
    @test size(ax) == size(axv)
    @test size(ax,1) == size(axv,1)
    @test ndims(ax) == 1
    @test length(ax) == length(axv)
    ax2 = YAXArrays.Cubes.Axes.axcopy(ax, axv)
    @test typeof(ax2) == typeof(ax)
    @test ax2.values == ax.values
    b = IOBuffer()
    show(b,ax)
    @test caxes(ax) == [ax]
    @test YAXArrays.Cubes.Axes.axname(ax) == axn
    @test YAXArrays.Cubes.axsym(ax) == Symbol(axn)
    #Test axVal2Index separately
    if ax isa CategoricalAxis
        for (i,v) in enumerate(axv)
            @test axVal2Index(ax,v) == i
            @test axVal2Index(ax,v[1:2], fuzzy=true) == i
        end
    else

end
end
