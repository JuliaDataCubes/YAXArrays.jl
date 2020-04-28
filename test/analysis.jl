using ESDL
using Test
using Dates
import Base.Iterators
using Distributed
using Statistics
addprocs(2)
@everywhere using ESDL, Statistics, ESDC, NetCDF

@everywhere function sub_and_return_mean(xout1,xout2,xin)
    m=mean(skipmissing(xin))
    for i=1:length(xin)
        xout1[i]=xin[i]-m
    end
    xout2[1]=m
end
function sub_and_return_mean(c)
  mapCube(sub_and_return_mean,c,
  indims=InDims("Time"),
  outdims=(OutDims("Time"),OutDims()))
end

function doTests()
  # Test simple Stats first
  c=Cube()

  d = subsetcube(c,variable="air_temperature_2m",lon=(10,11),lat=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

  dmem=readcubedata(d)

  @testset "Simple statistics using mapslices" begin
  # Basic statistics
  m=mapslices(mean∘skipmissing,d,dims = "Time")

  @test isapprox(readcubedata(m).data,[282.04703 281.84494 281.65927 282.2035;
    281.90726 281.59995 281.69135 282.38644;
    281.84158 281.35898 281.66083 282.49042;
    281.92462 281.12613 281.50513 282.4352])

  #Test Spatial meann along laitutde axis
  d1=subsetcube(c,variable="gross_primary_productivity",time=(Date("2002-01-01"),Date("2002-01-01")),lon=(30,30))

  dmem=readcubedata(d1)
  mtime=mapslices(mean∘skipmissing,dmem,dims = ("lon","lat"))

  end
  # Test Mean seasonal cycle retrieval
  @testset "Seasonal cycle statistics and anomalies" begin
  cdata=subsetcube(c,variable="soil_moisture",lon=10,lat=50.75)
  d=readcubedata(cdata)

  x2=getMSC(d)

  x3=getMedSC(d)

  a = d[:]
  a = a[3:46:end]
  @test isapprox(mean(skipmissing(a)),x2[3])
  @test isapprox(median(skipmissing(a)),x3[3])

  # Test gap filling
  cube_filled=readcubedata(gapFillMSC(d))
  imiss=findfirst(i->ismissing(i),d.data)
  @test !ismissing(cube_filled.data[imiss])
  its=mod(imiss-1,46)+1
  @test cube_filled.data[imiss]≈readcubedata(x2).data[its]
  @test !any(ismissing(cube_filled.data))

  # Test removal of MSC

  cube_anomalies=readcubedata(removeMSC(cube_filled))
  @test isapprox(cube_anomalies.data[47:92],(cube_filled.data[47:92].-readcubedata(x2).data[1:46]))


  # Test normalization
  anom_normalized=normalizeTS(cube_anomalies)[:]
  #@show cube_anomalies[:,:,:]
  @test mean(anom_normalized)<1e7
  @test 1.0-1e-6 <= std(anom_normalized) <= 1.0+1e-6

  #Test Polynomial fitting
  d = c[var = "soil_moisture"]
  dshort = d[time=2001:2003,lon=10.375,lat=51.125]
  dfill = gapFillMSC(dshort,complete_msc=true)
  @test all(!ismissing,dfill[:])
  @test dfill[1:10] == [0.20832627f0, 0.21695568f0, 0.24278758f0, 0.27789998f0, 0.39543962f0, 0.4276f0, 0.33524698f0, 0.23578292f0, 0.27228776f0, 0.27020702f0]
  @test gapfillpoly(dshort)[50:60] == [0.33521008f0, 0.32984155f0, 0.4276f0, 0.38669506f0, 0.35547495f0, 0.3271779f0, 0.30180392f0, 0.27935302f0, 0.25982517f0, 0.20553333f0, 0.22209999f0]
  end


  d1=subsetcube(c,variable=["gross_primary_productivity","net_ecosystem_exchange"],lon=(10,10),lat=(50,50))
  d2=subsetcube(c,variable=["gross_primary_productivity","air_temperature_2m"],lon=(10,10),lat=(50,50))


  @testset "Multiple output cubes" begin
  #Test onvolving multiple output cubes
  c1=subsetcube(c,variable="gross_primary_productivity",lon=(10,11),lat=(50,51),time=Date(2001)..Date(2010))

  c2=readcubedata(c1)

  cube_wo_mean,cube_means=sub_and_return_mean(c2)

  @test isapprox(permutedims(c2[:,:,:].-mean(c2[:,:,:],dims=3),(3,1,2)),readcubedata(cube_wo_mean)[:,:,:])
  @test isapprox(mean(c2[:,:,:],dims=3)[:,:,1],cube_means[:,:])
  end
end

@testset "Parallel processing" begin
doTests()
end
rmprocs(workers())

@testset "Single proc processing" begin
doTests()
end
