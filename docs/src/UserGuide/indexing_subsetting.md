# Indexing, subsetting and selectors

All these operations are done via [`DimensionalData.jl`](https://rafaqz.github.io/DimensionalData.jl/dev/).

````@example indexing
using YAXArrays, Dates
````

## Define a toy cube

````@ansi indexing
t = Date("2020-01-01"):Month(1):Date("2022-12-31")
axes = (Dim{:lon}(-9:10), Dim{:lat}(-5:15), Dim{:time}(t))
c = YAXArray(axes, reshape(1:20*21*36, (20, 21, 36)))
````

A very convinient selector is `lookup`, getting for example the values for `lon` and `time`.

## lookup

````@example indexing
lon = lookup(c, :lon)
````

````@example indexing
tempo = lookup(c, :time)
````


## Selectors

### `At` value

````@ansi indexing
c[time = At(DateTime("2021-05-01"))]
````

### `At` vector of values

````@ansi indexing
c[time = At([DateTime("2021-05-01"), DateTime("2021-06-01")])]
````

similarly for any of the spatial dimensions:

````@ansi indexing
c[lon = At([-9,-5])]
````

### `At` values with tolerance (`atol`, `rtol`)

````@ansi indexing
c[lon = At([-10, 11]; atol = 1)]
````
## Subsetting

This is also done with selectors, see the following examples

### Between

Altought a `Between(a,b)` function is available in `DimensionalData`, is recommended to use instead the `a .. b` notation:

````@ansi indexing
c[lon = -9 .. -7] # close interval, all points included.
````

More selectors from DimensionalData are available, such as `Touches`, `Near`, `Where` and `Contains`.


### Open/Close Intervals

````@example indexing
using IntervalSets
````

````@ansi indexing
c[lon = OpenInterval(-9, -7)]
````

````@ansi indexing
c[lon = ClosedInterval(-9, -7)]
````
````@ansi indexing
c[lon =Interval{:open,:closed}(-9,-7)]
````
````@ansi indexing
c[lon =Interval{:closed,:open}(-9,-7)]
````

See tutorials for use cases.