# Analysis

The CABLAB package comes with a list of predefined methods for statistical analysis.
The functions are defined to work on specific axes, for example a function that removes the
mean annual cycle will alway work an the time axis. It does not matter which other axes are defined
in the input cube, the function will simply loop over these.
All the functions are called using the `mapCube` function.

```@docs
mapCube
```

The function will then be applied to the whole cube
in a memory-efficient way, which means that chunks of data are read, processed and then saved in
the output cube. Whether the output cube is a `TempCube` or a `CubeMem` is decided by the system,
depending on if the calculation is parallel, and how large the output cube is.

Here follows a list of analysis function included in this package. If you have implemented or wrapped a method
that might be of interest to a broader community, please feel free to open a pull request.

## Seasonal cycles

```@autodocs
Modules = [CABLAB.Proc.MSC]
Private = false
```


## Outlier detection

```@autodocs
Modules = [CABLAB.Proc.Outlier]
Private = false
```


## Simple Statistics

Another typcial use case is the application of basic statistics like `sum`, `mean` and `std`.
We provide a convenience function `reduceCube`  

```@docs
reduceCube
```

Additional simple statistics functions are:

```@autodocs
Modules = [CABLAB.Proc.Stats]
Private = false
```


## Time series decomposition
```@autodocs
Modules = [CABLAB.Proc.TSDecomposition]
Private = false
```

## Cube transformations
```@autodocs
Modules = [CABLAB.Proc.CubeIO]
Private = false
```
