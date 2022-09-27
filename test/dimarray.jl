@testitem "DimensionalData mapcube" begin
    using DimensionalData
    using YAXArrays
    m = Array{Union{Int, Missing}}(undef, 4,2,10)
    for i in 1:size(m,3)
        m[:,1,i] .= i
        m[:,2,i] .= 2*i
    end
    m[1,1,3] = missing
    m[3,1,6:10] .=missing
    m[4,1,:] .= 10

    lon = Dim{:Lon}(1:4)
    lat = Dim{:Lat}(1:2)
    tim = Dim{:Time}(1:10)
    c = DimArray(m, (lon, lat, tim))
    indims = InDims("Time")
    outdims = OutDims()
    r = mapCube(c, indims=indims, outdims=outdims) do xout, xin
        xout .= sum(skipmissing(xin))
    end
    @test r[1,1] == 52
end