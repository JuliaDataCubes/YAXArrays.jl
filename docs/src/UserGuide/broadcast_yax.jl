using DimensionalData
using YAXArrays
using Dates
using Statistics

axlist = (
    Dim{:Ti}(Date("2021-12-01"):Day(1):Date("2022-12-31")),
    X(range(1, 10, length=10)),
    Y(range(1, 5, length=15)),
    Dim{:Variable}(["var1", "var2"]))
data = rand(396, 10, 15, 2)
ds = YAXArray(axlist, data)

tempo = dims(ds, Dim{:Ti})  # Dim{:Ti} and not Ti ! a yax thing maybe.
month_length = YAXArray((tempo,), daysinmonth.(tempo))

g_tempo = groupby(month_length, Dim{:Ti} => season(; start=December))

sum_days = sum.(g_tempo, dims=Dim{:Ti})
weights = map(./, g_tempo, sum_days)

g_ds = groupby(ds, Dim{:Ti} => season(; start=December))

g_ds_w = broadcast_dims.(*, DimArray.(weights), DimArray.(g_ds))

g_ds_w = broadcast_dims.(*, weights, g_ds)


# TODO 
# broadcast_dims.(*, weights, Ref(g_ds))
# g_ds_w = weights .* g_ds # the red (first dimension)
# sum.(g_ds_w, dims = Dim{:Ti})

