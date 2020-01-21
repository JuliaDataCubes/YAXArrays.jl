using ESDL
using Test

newcubedir = mktempdir()
ESDLdir(newcubedir)
# Download Cube subset
c = S3Cube()
cgermany = c[
  region = "Germany",
  var = ["gross", "net_ecosystem", "air_temperature_2m", "terrestrial_ecosystem", "soil_moisture"],
  time = 2000:2010
]
saveCube(cgermany,"germanycube", chunksize=(20,20,92,1))
ESDL.ESDLDefaults.cubedir[] = joinpath(newcubedir,"germanycube")

include("access.jl")
include("axes.jl")
include("analysis.jl")
#include("artype.jl")
include("transform.jl")
include("remap.jl")
include("table.jl")
include("tabletocube.jl")
