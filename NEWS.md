# News

## v0.3.0

- the plotting module was split out into a separate package called `CABLABPlots`, so please add this package if you want to use Plots
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
