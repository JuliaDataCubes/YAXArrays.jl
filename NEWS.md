# News

## v0.5.0

- the default missing value representation was switched to DataArrays, so by default you will see a DataArray inside an inner function
- if you choose to use `:mask` as missing value representation the actual data array and the mask will be passed as a tuple to the inner function, instead of being two separate arguments
- there were lots of changes in the internals of `mapCube` please open issues if you find old code not working anymore or you find some serious performance regressions
- there is a new method for registering functions available, which avoids all these nested tuples for the input and output dimensions. See

## v0.4.0

- the package was updated to julia 0.6
- a new cube type `TransformedCube` was introduced, to do simple element-wise operations without having to call `mapCube`
- so thing like adding scalars to cube, and elementwise operations between cubes are possible now
- see the demo notebook 02 for details
- the `reduceCube` backend was switched to `DataArrays`, so when calling the function you will see a DataArray inside with missings represented as `NA`


## v0.3.0

- the plotting module was split out into a separate package called `ESDLPlots`, so please add this package if you want to use Plots
- the time axis is now based on `Date` - and not on `DateTime` anymore. This means that some methods are not applicable on old datacubes anymore, so please be careful

## v0.2.1

* a new macro `@loadOrGenerate` was added to generate and save intermediate results or load them if already existent
* a wrapper to calculate Online PCAs was added with `cubePCA`
* a new map plotting function `plotMAPRGB` to generate RGB, Lab, HSV etc plots
* print cube size when showing cube info  

## v0.2

* a list of pre-defined lon-lat boxes was added that can be accessed when calling `getCubeData`, so for example `getCubeData(c,region="Germany")` will extract a Germany from the Cube.
* Support for masks was extended, this includes multiple changes:
  - every cube now has a `properties` field, which contains a `Dict{String,Any}` where additional cube propertyies can be stored
  - if an Integer-valued cube is used as a categorical mask one can add a Dict containg the mapping from value to label name to the cubes properties, eg `c.properties["labels"]=Dict(1=>"low",2=>"high")`
  - `plotMAP` will respect the defined label properties and use the labels for its legend
  - if a labeled cube is used in the `by` argument when fitting an `OnlineStat`, the output axis is automatically created
  - accessing a static variable (currently only water_mask or country_mask) through `getCubeData` will by default only return the first time step
