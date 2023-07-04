# # How to calculate a time mean

using YAXArrays, Statistics, Zarr
using DimensionalData
using Dates
axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-30")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"])
    )
# And the corresponding data
data = rand(30, 10, 15, 2)
ds = YAXArray(axlist, data)

c = ds[Variable = At("var1")] # see OpenNetCDF to get the file
mapslices(mean ∘ skipmissing, c, dims="Time")

# ## Distributed calculations
# It is possible to distribute the calculations over multiple process. The following code 
# does a time mean over all grid points using multiple CPU over a local machine.


#using Distributed
#addprocs(2)
#@everywhere using Pkg
#@everywhere Pkg.activate(".")
#@everywhere begin
#   using NetCDF
#   using YAXArrays
#   using Statistics
#   using Zarr
#end
#@everywhere function mymean(output, pixel)
#   @show "doing a mean"
#      output[:] .= mean(pixel)
#end
#indims = InDims("time")
#outdims = OutDims()
#resultcube = mapCube(mymean, c, indims=indims, outdims=outdims)

# In the last example, `mapCube` was used to map the `mymean` function. `mapslices` is a convenient function 
# that can replace `mapCube`, where you can omit defining an extra function with the output argument 
# as an input (e.g. `mymean`). It is possible to simply use `mapslice`

resultcube = mapslices(mean ∘ skipmissing, c, dims="time")

# ## SLURM cluster

# It is also possible to distribute easily the workload on a cluster, with little modification to the code. 
# The following code does a time mean over all grid points using multiple CPU over a SLURM cluster. 
# To do so, we use the `ClusterManagers` package.


#using Distributed
#using ClusterManagers
#addprocs(SlurmManager(10))
#@everywhere using Pkg
#@everywhere Pkg.activate(".")
#@everywhere using ESDL
#@everywhere using Statistics
#inpath="zg1000_AERday_CanESM5_esm-hist_r6i1p1f1_gn_18500101-20141231.nc"
#c = Cube(inpath, "zg1000")
#resultcube = mapslices(mean ∘ skipmissing, c, dims="time")