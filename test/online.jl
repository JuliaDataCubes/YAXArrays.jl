using ESDL
using Test
using Random
using Statistics
using OnlineStats
@testset "OnlineStats" begin
c=Cube()

d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
              time=(Date("2002-01-01"),Date("2008-12-31")))

mytable = @CubeTable tair=d axes=(lat,)



d2=readcubedata(d)

@test mean(d2.data) ≈ oo.data[1]
@test mean(d2.data,dims=(1,3))[:] ≈ oo2.data

#Test KMeans
d2 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
              time=(Date("2002-01-01"),Date("2008-12-31")))

dm=readcubedata(d2)
xin=permutedims(dm.data,[4,1,2,3])
xin=reshape(xin,(2,length(xin) ÷ 2))
startVal=mean(xin,dims=2)[:].+rand(Float32,2,5)

x=mapCube(KMeans,d2,5,2,MDAxis=VariableAxis)

o2=KMeans(2,5)
o2.value[:]=startVal
fit!(o2,xin')
@test all(isapprox.(OnlineStats.value(o2),x.data))

#Test covariance Matrix
covmat,means = mapCube(CovMatrix,dm,MDAxis=VariableAxis)

@test all(isapprox.(covmat.data,cov(reshape(dm.data,length(dm.data) ÷ 2,2))))

using ESDL
using DataStructures
c=Cube()
d2 = getCubeData(c,variable=["air_temperature_2m","gross_primary_productivity"],longitude=(30,31),latitude=(50,51),
              time=(Date("2002-01-01"),Date("2008-12-31")))
dm=readcubedata(d2)

randmask=CubeMem(dm.axes[1:2],rand(1:2,size(dm)[1:2]),zeros(UInt8,size(dm)[1:2]),
  Dict{String,Any}("labels"=>OrderedDict(1=>"one",2=>"two"),"name"=>"RandMask"))


#Test PCA
m1=randmask.data.==1
m2=randmask.data.==2
ii2=findall(m2)
for i=1:length(ii2)
  dm.data[ii2[i],:,:]=rand(322,2)
end



p=cubePCA(dm,by=[randmask],noutdims=2)

println((explained_variance(p)).data[1, 1])

@test all([0.984 0.45; 0.09 0.45] .< explained_variance(p).data[1,1])
rotation_matrix(p)
transformPCA(p,dm).data

Random.seed!(1)
d2=readcubedata(d)
mask=CubeMem(d2.axes,rand(1:10,size(d2.data)),zeros(UInt8,size(d2.data)),Dict("labels"=>Dict(i=>string(i) for i=1:10)))
mask2=CubeMem(d2.axes[1:2],rand(1:10,4,4),zeros(UInt8,4,4),Dict("labels"=>Dict(i=>string(i) for i=1:10)))

oogrouped = mapCube(Mean,d2,by=(mask,))
@test isa(oogrouped.axes[1],CategoricalAxis{String,:Label})

oogrouped2 = mapCube(Mean,d2,by=(mask2,))

for k=1:10
  know = findfirst(j->j==string(k),oogrouped2.axes[1].values)
  @test oogrouped.data[know] ≈ mean(d2.data[mask.data.==k])

  i=findall(mask2.data.==k)

  if length(i) > 0
    dhelp=Float32[]
    for jj in i
      append!(dhelp,d2.data[jj,:])
    end
    @test mean(dhelp) ≈ oogrouped2.data[know]
  end
end

end
