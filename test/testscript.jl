using YAXArrays
using DimensionalData
using Zarr

ds = open_dataset("/home/fcremer/Daten/thuringia/hainich_tile_D_sub.zarr/")

ds

subs = ds.layer[X(-390060 .. -390000), Y(-670060 .. -670000),Ti(1:10)]
set(subs, X => 1:3)

subsarr =subs.data[:,:,:,:]
ds.layer
using Statistics
mapslices(mean ∘ skipmissing, subs, dims="Time")[:,:,1,1]

mapslices(mean ∘ skipmissing, subsarr, dims=3)[:,:,1,1]

