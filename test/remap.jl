@testset "Resampling" begin
  c=Cube()
  d=getCubeData(c,variable="gross_primary_productivity",region="Germany",time=(Date(2001,1,1),Date(2001,1,15)))
  newlons=5.875:0.05:14.875
  newlats=54.875:-0.05:47.375
  shigh = spatialinterp(d,newlons,newlats)
  @test d[37,31,1]==shigh[181,151,1]
  @test d[37,30,1]==shigh[181,146,1]
end
