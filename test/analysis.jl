using CABLAB
using Base.Test

addprocs(2)
@everywhere using CABLAB, DataArrays

@everywhere function catCubes(xout,xin1,xin2)
    Ntime,nvar1=size(xin1)
    nvar2=size(xin2,2)
    for ivar=1:nvar1
        for itime=1:Ntime
            xout[itime,ivar]=xin1[itime,ivar]
          end
        end
    for ivar=1:nvar2
        for itime=1:Ntime
            xout[itime,nvar1+ivar]=xin2[itime,ivar]
          end
    end
end
registerDATFunction(catCubes,((TimeAxis,"Variable"),("Time",VariableAxis)),(TimeAxis,CategoricalAxis("Variable2",[1,2,3,4])),inmissing=(NaN,NaN),outmissing=:nan)

@everywhere function sub_and_return_mean(xout1,xout2,xin)
    m=mean(filter(isfinite,xin))
    for i=1:length(xin)
        xout1[i]=xin[i]-m
    end
    xout2[1]=m
end
registerDATFunction(sub_and_return_mean,(TimeAxis,),((TimeAxis,),()),inmissing=:nan,outmissing=(:nan,:nan))


function doTests()
  # Test simple Stats first
  c=RemoteCube()

  d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(Date("2002-01-01"),Date("2008-12-31")))

  dmem=readCubeData(d)

  # Basic statistics
  m=reduceCube(mean,d,TimeAxis,skipmissing=true)

  @test isapprox(readCubeData(m).data,[281.922  282.038  282.168  282.288;
                281.936  282.062  282.202  282.331;
                281.949  282.086  282.236  282.375;
                281.963  282.109  282.271  282.418])

  #Test Spatial meann along laitutde axis
  d1=getCubeData(c,variable="gross_primary_productivity",time=(Date("2002-01-01"),Date("2002-01-01")),longitude=(30,30))

  dmem=readCubeData(d1)
  mtime=reduceCube(mean,dmem,("lon","lat"),skipmissing=true)

  wv=cosd.(dmem.axes[2].values)
  goodinds=dmem.mask.==0x00
  # the element-wise operations are right now a problem with the julia 0.6
  #@test Float32(sum(dmem.data[goodinds].*wv[goodinds])/sum(wv[goodinds]))==readCubeData(mtime).data[1]

  # Test Mean seasonal cycle retrieval

  cdata=getCubeData(c,variable="soil_moisture",longitude=(30,30),latitude=(50.75,50.75))
  d=readCubeData(cdata)
  x2=mapCube(getMSC,d)
  x3=mapCube(getMedSC,d)
  dstep3=d.data[1,1,3:46:506]
  mstep3=d.mask[1,1,3:46:506]
  @test mean(dstep3[mstep3.==0x00])==readCubeData(x2).data[3]
  @test median(dstep3[mstep3.==0x00])==readCubeData(x3).data[3]

  # Test gap filling
  cube_filled=readCubeData(mapCube(gapFillMSC,d))
  imiss=findfirst(d.mask)
  @test cube_filled.mask[imiss]==CABLAB.Mask.FILLED
  its=mod(imiss-1,46)+1
  @test cube_filled.data[imiss]≈readCubeData(x2).data[its]
  @test !any(cube_filled.mask.==CABLAB.Mask.MISSING)

  # Test removal of MSC

  cube_anomalies=readCubeData(mapCube(removeMSC,cube_filled))
  @test isapprox(cube_anomalies.data[47:92],(cube_filled.data[47:92].-readCubeData(x2).data[1:46]))

  # Test normalization
  anom_normalized=readCubeData(mapCube(normalizeTS,cube_anomalies))
  @test mean(anom_normalized.data)<1e7
  @test 1.0-1e-6 <= std(anom_normalized.data) <= 1.0+1e-6
  #test anomaly detection

  d3=getCubeData(c,variable=["gross_primary_productivity","air_temperature_2m"],longitude=(30,30),latitude=(50.75,50.75))
  anom_new=mapCube(removeMSC,d3)
  anom_norm=readCubeData(mapCube(normalizeTS,anom_new))
  anoms_detected = mapCube(DAT_detectAnomalies!,anom_norm,["KDE","T2","REC"],reshape(Float64.(anom_norm.data),(506,2)))

# Test generation of new axes

  d1=getCubeData(c,variable=["gross_primary_productivity","net_ecosystem_exchange"],longitude=(30,30),latitude=(50,50))
  d2=getCubeData(c,variable=["gross_primary_productivity","air_temperature_2m"],longitude=(30,30),latitude=(50,50))

  ccube=mapCube(catCubes,(d1,d2))

  #Test Quantiles
  cdata=getCubeData(c,variable=["soil_moisture","gross_primary_productivity"],longitude=(30,30),latitude=(50.75,50.75))
  o=readCubeData(mapCube(timelonlatquantiles,cdata,[0.1,0.5,0.9]))
  o2=readCubeData(cdata)
  size(o2.data)
  o2=o2.data[:,:,:,1][o2.mask[:,:,:,1].==0x00]
  @test quantile(o2,[0.1,0.5,0.9])==o.data[:,1]

  nothing
  #Test onvolving multiple output cubes
  c1=getCubeData(c,variable="gross_primary_productivity",longitude=(30,31),latitude=(50,51))

  c2=readCubeData(c1)

  cube_wo_mean,cube_means=mapCube(sub_and_return_mean,c2)

  @test isapprox(permutedims(c2.data.-mean(c2.data,3),(3,1,2)),readCubeData(cube_wo_mean).data)
  @test isapprox(mean(c2.data,3)[:,:,1],readCubeData(cube_means).data)
end

doTests()
rmprocs(workers())

doTests()
