using ESDL
using Test
using Dates
import Base.Iterators
using Distributed
using Statistics
#addprocs(2)
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

  d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

  dmem=readCubeData(d)

  @testset "Simple statistics using reduceCube" begin
  # Basic statistics
  m=mapslices(mean∘skipmissing,d,"Time")

  @test isapprox(readCubeData(m).data,[281.922  282.038  282.168  282.288;
                281.936  282.062  282.202  282.331;
                281.949  282.086  282.236  282.375;
                281.963  282.109  282.271  282.418])

  #Test Spatial meann along laitutde axis
  d1=getCubeData(c,variable="gross_primary_productivity",time=(Date("2002-01-01"),Date("2002-01-01")),longitude=(30,30))

  dmem=readCubeData(d1)
  mtime=mapslices(mean∘skipmissing,dmem,("lon","lat"))

  end
  # Test Mean seasonal cycle retrieval
  @testset "Seasonal cycle statistics and anomalies" begin
  cdata=getCubeData(c,variable="soil_moisture",longitude=(30,30),latitude=(50.75,50.75))
  d=readCubeData(cdata)

  x2=getMSC(d)

  x3=getMedSC(d)

  a = d[1,1,:]
  a = a[3:46:end]
  @test mean(skipmissing(a))==x2[3,1,1]
  @test median(skipmissing(a))==x3[3,1,1]

  # Test gap filling
  cube_filled=readCubeData(gapFillMSC(d))
  imiss=findfirst(i->i==0x01,d.mask)
  @test cube_filled.mask[imiss]==ESDL.Mask.FILLED
  its=mod(imiss.I[3]-1,46)+1
  @test cube_filled.data[imiss]≈readCubeData(x2).data[its]
  @test !any(cube_filled.mask.==ESDL.Mask.MISSING)

  # Test removal of MSC

  cube_anomalies=readCubeData(removeMSC(cube_filled))
  @test isapprox(cube_anomalies.data[47:92],(cube_filled.data[47:92].-readCubeData(x2).data[1:46]))


  # Test normalization
  anom_normalized=readCubeData(normalizeTS(cube_anomalies))
  @test mean(anom_normalized.data)<1e7
  @test 1.0-1e-6 <= std(anom_normalized.data) <= 1.0+1e-6
  end


  d1=getCubeData(c,variable=["gross_primary_productivity","net_ecosystem_exchange"],longitude=(30,30),latitude=(50,50))
  d2=getCubeData(c,variable=["gross_primary_productivity","air_temperature_2m"],longitude=(30,30),latitude=(50,50))


  @testset "Multiple output cubes" begin
  #Test onvolving multiple output cubes
  c1=getCubeData(c,variable="gross_primary_productivity",longitude=(30,31),latitude=(50,51))

  c2=readCubeData(c1)

  cube_wo_mean,cube_means=sub_and_return_mean(c2)

  @test isapprox(permutedims(c2.data.-mean(c2.data,dims=3),(3,1,2)),readCubeData(cube_wo_mean).data)
  @test isapprox(mean(c2.data,dims=3)[:,:,1],readCubeData(cube_means).data)
  end
end

@testset "Parallel processing" begin
doTests()
end
rmprocs(workers())

@testset "Single proc processing" begin
doTests()
end
