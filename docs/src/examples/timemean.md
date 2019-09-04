## How to calculate a time mean

````@jldoctest
using ESDL
c = Cube()
citaly = c[var = ["air_temperature_2m", "evaporation"], region="Italy", time=2001:2003]
mapslices(mean ∘ skipmissing, c, dims="Time")
