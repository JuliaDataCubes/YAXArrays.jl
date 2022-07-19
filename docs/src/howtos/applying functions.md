## Mapping functions over YAXArrays

To apply user defined functions on a YAXArray data type we can use the `map` function, `mapslices` function or the `mapCube` function. 
Which of these functions should be used depends on the layout of the data  that the functions should be applied on. 

### `map` function 

The `map` function can be used to apply a function on every entry of a YAXArray without taking the dimensions into account. This will lazily register the mapped function which is applied when the YAXArray is either accessed or when more involved computations are made. 

```@docs
map(::YAXArray)

```

### `mapslices` function

If an function should work along a certain slice of the data you can use the 'mapslices' function to easily apply this function. 


