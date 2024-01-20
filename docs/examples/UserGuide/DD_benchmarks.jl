using YAXArrays, YAXArrayBase, DimensionalData, BenchmarkTools

yax = YAXArray(rand(10, 20, 5))
dd = yaxconvert(DimArray, yax)

@benchmark yax[Dim_1=1:3]

@benchmark yax[Dim_1=1:3]

@benchmark dd[Dim_1=1:3]