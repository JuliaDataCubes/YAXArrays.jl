using Test

@testset "Batch extraction along multiple axes" begin 
lons = range(30,35,step=0.25)
lats = range(50,55,step=0.25)
times = Date(2000,1,1):Month(1):Date(2000,12,31)

data = rand(length(lons),length(lats), length(times));

c = YAXArray([RangeAxis("longitude",lons),RangeAxis("latitude",lats),RangeAxis("time",times)],data)
c_perm = permutedims(c,(3,2,1))


sites_names = [(lon = rand()*5+30, lat = rand()*5+50,site = string(i)) for i in 1:200]
sites_pure = [(lon = n.lon, lat=n.lat) for n in sites_names]
lon,lat = sites_pure[10]

r = c[sites_names]
@test r isa YAXArray
@test YAXArrays.Cubes.axname.(caxes(r)) == ["site","time"]
@test r.site.values == string.(1:200)
@test all(isequal.(c[lon=lon,lat=lat][:], r[10,:]))

r = c_perm[sites_names]
@test r isa YAXArray
@test YAXArrays.Cubes.axname.(caxes(r)) == ["time","site"]
@test r.site.values == string.(1:200)
@test all(isequal.(c[lon=lon,lat=lat][:], r[:,10]))

r = c[sites_pure]
@test r isa YAXArray
@test YAXArrays.Cubes.axname.(caxes(r)) == ["longitude_latitude","time"]
map(r.longitude_latitude.values,[(n.lon,n.lat) for n in sites_pure]) do ll, ll_real
    abs(ll[1]-ll_real[1]) <= 0.125 && abs(ll[2]-ll_real[2]) <= 0.125
end |> all
@test all(isequal.(c[lon=lon,lat=lat][:], r[10,:]))

r = c_perm[sites_pure]
@test r isa YAXArray
@test YAXArrays.Cubes.axname.(caxes(r)) == ["time","longitude_latitude"]
map(r.longitude_latitude.values,[(n.lon,n.lat) for n in sites_pure]) do ll, ll_real
    abs(ll[1]-ll_real[1]) <= 0.125 && abs(ll[2]-ll_real[2]) <= 0.125
end |> all
@test all(isequal.(c[lon=lon,lat=lat][:], r[:,10]))

othersites = [(lon=32.0,time=Date(2000,6,1),point=3),(lon=33.0,time=Date(2000,7,1),point=5)]
r = c[othersites]
@test r isa YAXArray
@test YAXArrays.Cubes.axname.(caxes(r)) == ["point","latitude"]
@test r.point.values == [3,5]
@test c[lon=33.0,time=Date(2000,7,1)][:] == r[point=5][:]

end