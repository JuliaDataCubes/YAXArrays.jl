## How to apply functions on YAXArrays

To apply user defined functions on a YAXArray data type we can use the [`map`](@ref) function, [`mapslices`](@ref) function or the [`mapCube`](@ref) function. 
Which of these functions should be used depends on the layout of the data,  that the user defined function should be applied on. 

### Apply a function on every element of a datacube

The `map` function can be used to apply a function on every entry of a YAXArray without taking the dimensions into account. This will lazily register the mapped function which is applied when the YAXArray is either accessed or when more involved computations are made. 

If we set up a dummy data cube which has all numbers between 1 and 10000.
```@example map
    using YAXArrays
    axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", 1:100)]
    original = YAXArray(axes, reshape(1:10000, (10,10,100)))
```

with one at the first position:

```@example map
original[1,:,1]
```

now we can substract `1` from all elements of this cube

```@example map
    substracted = map(x-> x-1, original)
```

`substracted` is a cube of the same size as `original`, and the applied function is registered, so that it is applied as soon as the elements of `substracted` are either accessed or further used in other computations. 

```@example map
    substracted[1,:,1]
```


### Apply a function along dimensions of a single cube

If an function should work along a certain dimension of the data you can use the 'mapslices' function to easily apply this function. This doesn't give you the flexibility of the `mapCube` function but it is easier to use for simple functions. 

If we set up a dummy data cube which has all numbers between 1 and 10000.
```@example mapslice
    using YAXArrays
    axes = [RangeAxis("Lon", 1:10), RangeAxis("Lat", 1:10), RangeAxis("Time", 1:100)]
    original = YAXArray(axes, reshape(1:10000, (10,10,100)))
```

and then we would like to compute the sum over the Time dimension:
```@example mapslice
    timesum = mapslices(sum, original, dims="Time")
```
this reduces over the time dimension and gives us the following values
```@example mapslice
    timesum[:,:]
```

You can also apply a function along multiple dimensions of the same data cube. 
```@example mapslice
    lonlatsum = mapslices(sum, original, dims=("Lon", "Lat"))
```

### How to combine multiple cubes in one computation



