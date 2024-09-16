using YAXArrays, Dates

axlist = (
    Dim{:time}(Date("2022-01-01"):Day(1):Date("2022-01-10")),
    Dim{:lon}(range(1, 10, length=10)),
    Dim{:lat}(range(1, 5, length=15)),
    Dim{:variables}(["a", "b"])
)
data = rand(10, 10, 15, 2)
properties = Dict(:description => "multi dimensional test cube")
a = YAXArray(axlist, data, properties)

