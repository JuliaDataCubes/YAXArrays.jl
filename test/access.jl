using ESDL
using Test
using Dates
#Open a remote cube
@testset "Cube Access" begin

c=Cube()

@testset "Access single variable" begin
d = subsetcube(c,variable="air_temperature_2m",lon=(30,31),lat=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))


@test d.subset==(841:844, 157:160, 1013:1334)
@test d.axes[1].values==30.125:0.25:30.875
@test d.axes[2].values==50.875:-0.25:50.125
@test isa(d.axes[1],LonAxis)
@test isa(d.axes[2],LatAxis)
end

@testset "Access multiple variables" begin
d2 = subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"],lon=(30,31),lat=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

@test d2.cataxis.values == ["air_temperature_2m", "gross_primary_productivity"]
foreach(d2.cubelist) do cc
  @test cc.subset ==(841:844, 157:160, 1013:1334)
  @test cc.axes[1].values==30.125:0.25:30.875
  @test cc.axes[2].values==50.875:-0.25:50.125
  @test first(cc.axes[3].values) == Dates.Date(2002,1,5)
  @test last(cc.axes[3].values) == Dates.Date(2008, 12, 30)
end
end

@testset "Test values in MemCube" begin
d = subsetcube(c,variable="air_temperature_2m",lon=(30,31),lat=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))
d2 = subsetcube(c,variable=["air_temperature_2m","gross_primary_productivity"],lon=(30,31),lat=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))
data1=readcubedata(d)
data2=readcubedata(d2)

@test size(data1.data)==(4,4,322)
@test size(data2.data)==(4,4,322,2)


@test isapprox(data1.data[1,1,1:10],Float32[264.868, 270.255, 270.913, 276.689, 277.946,
 276.293, 273.928, 275.789, 279.696, 277.055])

@test isapprox(data2.data[1,1,1:10,1],Float32[264.868, 270.255, 270.913, 276.689, 277.946,
276.293, 273.928, 275.789, 279.696, 277.055])

@test caxes(data1)[1:2]==CubeAxis[LonAxis(30.125:0.25:30.875),LatAxis(50.875:-0.25:50.125)]

tax = caxes(data1)[3]
@test isa(tax, TimeAxis)
@test tax.values[1] == Date(2002,01,05)
@test tax.values[end] == Date(2008,12,30)
@test length(tax.values) == 7*46

@test caxes(data2)[[1,2,4]]==CubeAxis[LonAxis(30.125:0.25:30.875),LatAxis(50.875:-0.25:50.125),VariableAxis(["air_temperature_2m","gross_primary_productivity"])]

tax = caxes(data2)[3]
@test isa(tax, TimeAxis)
@test tax.values[1] == Date(2002,01,05)
@test tax.values[end] == Date(2008,12,30)
@test length(tax.values) == 7*46

end

@testset "Coordinate extraction" begin
d = subsetcube(c,variable="air_temperature_2m",lon=(30,31),lat=(51,50),
                time=(Date("2002-01-01"),Date("2008-12-31")))
data1=readcubedata(d)
# Test reading of coordinate list
ll=[30.1 50.2;30.5 51.1;30.8 51.1]
llcube = readcubedata(extractLonLats(data1,ll))
@test llcube.data[1,:]==data1.data[1,4,:]
@test llcube.data[2,:]==data1.data[3,1,:]
@test llcube.data[3,:]==data1.data[4,1,:]
end

@testset "Accessing regions" begin
#Test access datacube by region
d3 = subsetcube(c,variable="gross_primary_productivity",region="Cambodia",time=Date("2005-01-01"))
@test d3.axes==[LonAxis(102.375:0.25:107.375),LatAxis(14.625:-0.25:10.625)]
end

@testset "Saving and loading cubes" begin
  d = subsetcube(c,variable="air_temperature_2m",lon=(30,31),lat=(51,50),
                  time=(Date("2002-01-01"),Date("2008-12-31")))
  data1=readcubedata(d)
  #Test saving cubes
  dire=tempname()
  ESDLdir(dire)
  saveCube(data1,"mySavedCube")


  data3=readcubedata(loadCube("mySavedCube"))
  @test data1.axes==data3.axes
  @test data1.data==data3.data

  # Test loadOrGenerate macro
  d=subsetcube(c,time=Date(2001)..Date(2005),lon=(30,31),lat=(50,51),variable=["gross_primary_productivity","net_ecosystem_exchange"])

  rmCube("Anomalies")
  @loadOrGenerate danom=>"Anomalies" begin
      danom = removeMSC(d)
  end

  @test danom isa ESDL.CubeMem

  @loadOrGenerate danom=>"Anomalies" begin
      error("This should never execute")
  end;
  @test danom isa ESDL.Cubes.ESDLZarr.ZArrayCube

  saveCube(danom, "mySavedZArrayCube")

  @test danom isa ESDL.Cubes.ESDLZarr.ZArrayCube

  danom=readcubedata(danom)
  danom2=readcubedata(loadCube("mySavedZArrayCube"))

  @test danom.axes==danom2.axes
  @test danom.data==danom2.data

  ncf = tempname()
  exportcube(danom,ncf)

  using NetCDF, Dates
  #Test exportcube
  @test ncread(ncf,"Lon") == 30.125:0.25:30.875
  @test ncread(ncf,"Lat") == 50.875:-0.25:50.125
  @test ncgetatt(ncf,"Time","units") == "days since 2001-01-01"
  @test getAxis("Time",danom).values .- DateTime(2001) == Millisecond.(Day.(ncread(ncf,"Time")))


  @test ncread(ncf,"gross_primary_productivity")[:,:,:] == permutedims(danom[:,:,:,1],(2,3,1))
  neear = replace(danom[:,:,:,2],missing=>-9999.0)
  @test all(isequal.(ncread(ncf,"net_ecosystem_exchange")[:,:,:],permutedims(neear,(2,3,1))))
end
end
