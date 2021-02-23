using Pkg

using YAXArrays
using BenchmarkTools

const SUITE = BenchmarkGroup()
SUITE["mapslices"] = include("bench_mapslices.jl")
