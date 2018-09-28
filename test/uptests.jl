using Revise
using ESDL
using ZarrNative
using ESDLZarr
c=Cube(zopen("/home/fgans/zarr/New Download/esdc-8d-0.25deg-1x720x1440-1.0.1_1_zarr/"))

d = getCubeData(c,variable="gross_primary_productivity")

typeof(d)

methods(ESDL.CubeAPI.cubechunks)
