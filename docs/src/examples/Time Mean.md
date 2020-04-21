## How to calculate a time mean

````@jldoctest
using ESDL
c = Cube()
citaly = c[var = ["air_temperature_2m", "evaporation"], region="Italy", time=2001:2003]
mapslices(mean ∘ skipmissing, c, dims="Time")
````

## Distributed calculations

### Local machine

It is possible to distribute the calculations over multiple process. The following code does a time mean over all grid points using multiple CPU over a local machine.

````julia
using Distributed
addprocs(2)

@everywhere using Pkg
@everywhere Pkg.activate(".")
@everywhere using ESDL
@everywhere using Statistics

@everywhere function mymean(output, pixel)
       output = mean(pixel)
end

c = Cube()
tair = subsetcube(c,variable="air_temperature_2m", time=2001:2016)
tair_c = map(t->t-273.15, tair)

indims = InDims(TimeAxis)
outdims = OutDims()

resultcube = mapCube(mymean, tair_c, indims=indims, outdims=outdims)
````

In the last example, `mapCube` was used to map the `mymean` function. `mapslices` is a convenient function that can replace `mapCube`, where you can omit defining an extra function with the output argument as an input (e.g. `mymean`). It is possible to simply use `mapslice`

```julia
resultcube = mapslices(mean ∘ skipmissing, c, dims="time")
```

### SLURM cluster

It is also possible to distribute easily the workload on a cluster, with little modification to the code. The following code does a time mean over all grid points using multiple CPU over a SLURM cluster. To do so, we use the `ClusterManagers` package.

```julia
using Distributed
using ClusterManagers

addprocs(SlurmManager(10))

@everywhere using Pkg
@everywhere Pkg.activate(".")
@everywhere using ESDL
@everywhere using Statistics

inpath="zg1000_AERday_CanESM5_esm-hist_r6i1p1f1_gn_18500101-20141231.nc"

c = Cube(inpath, "zg1000")

resultcube = mapslices(mean ∘ skipmissing, c, dims="time")
```
