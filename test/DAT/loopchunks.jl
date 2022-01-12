
@testset "Loop chunk distribution" begin
using DiskArrays: DiskArrays, GridChunks, RegularChunks, IrregularChunks
using YAXArrayBase: YAXArrayBase
struct LargeDiskArray{N,CT<:GridChunks{N}} <: AbstractDiskArray{Float64,N}
    size::NTuple{N,Int}
    chunks::CT
    compressed::Bool
end
Base.size(a::LargeDiskArray) = a.size
DiskArrays.eachchunk(a::LargeDiskArray) = a.chunks
DiskArrays.haschunks(::LargeDiskArray) = DiskArrays.Chunked()
YAXArrayBase.iscompressed(a::LargeDiskArray) = a.compressed
s = (4000,2000,1500)
cs = (100,100,700)
YAXArrays.YAXDefaults.max_cache[] = 1.0e8
a1 = YAXArray(LargeDiskArray(s, GridChunks(s,cs),true))

#Test case where chunk has to be split
dc = mapslices(sum, a1, dims="Dim_1", debug = true)
ch = YAXArrays.DAT.getloopchunks(dc)

@test length(ch) == 2
@test ch[1] == RegularChunks(4,0,2000)
@test ch[2] == RegularChunks(700,0,1500)
dc.outcubes[1].cube
# Test that the allocated buffer is close to what the prescribes size
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc);
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0;


#Test subsets and offset
a2 = a1[Dim_3=200..1300.5]
dc = mapslices(sum, a2, dims="Dim_1", debug = true)
ch = YAXArrays.DAT.getloopchunks(dc)
@test ch == (RegularChunks(4,0,2000), RegularChunks(700,200,1100))
# Test that the allocated buffer is close to what the prescribes size
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc);
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0;

#Test with different max_cache
YAXArrays.YAXDefaults.max_cache[] = 2.0e8
dc = mapslices(sum, a2, dims="Dim_1", debug = true)
ch = YAXArrays.DAT.getloopchunks(dc)
#Test loop chunk sizes
@test ch == (RegularChunks(8,0,2000), RegularChunks(700,200,1100))
# Test that the allocated buffer is close to what the prescribes size
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc);
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0# Test that the allocated buffer is close to what the prescribes size


# Test case that is chunk-friendly
YAXArrays.YAXDefaults.max_cache[] = 1.5e8
dc = mapslices(sum, a1, dims="Dim_3", debug = true)
ch = YAXArrays.DAT.getloopchunks(dc)
@test ch == (RegularChunks(100,0,4000), RegularChunks(100,0,2000))
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc)
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0# Test that the allocated buffer is close to what the prescribes size

#With offset
a2 = a1[Dim_1=50..3050.5]
dc = mapslices(sum, a2, dims="Dim_3", debug = true)
ch = YAXArrays.DAT.getloopchunks(dc)
@test ch == (RegularChunks(100,50,3000), RegularChunks(100,0,2000))
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc)
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0# Test that the allocated buffer is close to what the prescribes size

#With more working memory 
YAXArrays.YAXDefaults.max_cache[] = 4.5e8
a2 = a1[Dim_1=50..3050.5]
dc = mapslices(sum, a1, dims="Dim_3", debug = true);
ch = YAXArrays.DAT.getloopchunks(dc)
@test ch == (RegularChunks(300,0,4000), RegularChunks(100,0,2000))
incubes, outcubes = YAXArrays.DAT.getCubeCache(dc);
@test 0.5 < (sum(sizeof,incubes) + sum(sizeof,outcubes))/YAXArrays.YAXDefaults.max_cache[] <= 1.0# Test that the allocated buffer is close to what the prescribes size
end
