using Pkg
tempdir = mktempdir()
Pkg.activate(tempdir)
Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))
Pkg.add(["BenchmarkTools", "PkgBenchmark", "Random"])
Pkg.resolve()

using YAXArrays
using BenchmarkTools

const SUITE = BenchmarkGroup()
SUITE["mapCube"] = include("bench_mapcube.jl")
