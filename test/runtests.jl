using ESDL
using Test
#Make sure S3 cube is always accessed for tests
using Pkg
Pkg.add(PackageSpec(name="AWSCore", rev="master"))

delete!(ENV,"ESDL_CUBEDIR")

include("access.jl")
include("axes.jl")
include("analysis.jl")
include("artype.jl")
include("transform.jl")
include("remap.jl")
include("table.jl")
include("tabletocube.jl")
