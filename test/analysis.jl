using ESDL
using Test
using Dates
import Base.Iterators
using Distributed
using Statistics
addprocs(2)
@everywhere using ESDL, Statistics

@everywhere function sub_and_return_mean(xout1,xout2,xin)
    m=mean(skipmissing(xin))
    for i=1:length(xin)
        xout1[i]=xin[i]-m
    end
    xout2[1]=m
end
function sub_and_return_mean(c::ESDL.AbstractCubeData)
  mapCube(sub_and_return_mean,c,
  indims=InDims("Time"),
  outdims=(OutDims("Time"),OutDims()))
end

function doTests()
  # Test simple Stats first
  c=Cube()

  d = subsetcube(c,variable="air_temperature_2m",lon=(30,31),lat=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

  dmem=readcubedata(d)

  @testset "Simple statistics using mapslices" begin
  # Basic statistics
  m=mapslices(mean∘skipmissing,d,dims = "Time")

  @test isapprox(readcubedata(m).data,[281.598 281.657 281.595 281.639;
   281.687 281.731 281.692 281.722;
   281.734 281.779 281.787 281.816;
   281.694 281.775 281.879 281.933])

  #Test Spatial meann along laitutde axis
  d1=subsetcube(c,variable="gross_primary_productivity",time=(Date("2002-01-01"),Date("2002-01-01")),lon=(30,30))

  dmem=readcubedata(d1)
  mtime=mapslices(mean∘skipmissing,dmem,dims = ("lon","lat"))

  end
  # Test Mean seasonal cycle retrieval
  @testset "Seasonal cycle statistics and anomalies" begin
  cdata=subsetcube(c,variable="soil_moisture",lon=30,lat=50.75)
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
  end


  d1=subsetcube(c,variable=["gross_primary_productivity","net_ecosystem_exchange"],lon=(30,30),lat=(50,50))
  d2=subsetcube(c,variable=["gross_primary_productivity","air_temperature_2m"],lon=(30,30),lat=(50,50))


  @testset "Multiple output cubes" begin
  #Test onvolving multiple output cubes
  c1=subsetcube(c,variable="gross_primary_productivity",lon=(30,31),lat=(50,51),time=Date(2001)..Date(2010))

  c2=readcubedata(c1)

  cube_wo_mean,cube_means=sub_and_return_mean(c2)

  @test isapprox(permutedims(c2[:,:,:].-mean(c2[:,:,:],dims=3),(3,1,2)),readcubedata(cube_wo_mean)[:,:,:])
  @test isapprox(mean(c2[:,:,:],dims=3)[:,:,1],cube_means[:,:])
  end
end

@testset "Parallel processing" begin
doTests()
end
#rmprocs(workers())

@testset "Single proc processing" begin
doTests()
end
