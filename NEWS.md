# News

## v0.2

* a list of pre-defined lon-lat boxes was added that can be accessed when calling `getCubeData`, so for example `getCubeData(c,region="Germany")` will extract a Germany from the Cube.
* Support for masks was extended, this includes multiple changes:
  - every cube now has a `properties` field, which contains a `Dict{String,Any}` where additional cube propertyies can be stored
  - if an Integer-valued cube is used as a categorical mask one can add a Dict containg the mapping from value to label name to the cubes properties, eg `c.properties["labels"]=Dict(1=>"low",2=>"high")`
  - `plotMAP` will respect the defined label properties and use the labels for its legend
  - if a labeled cube is used in the `by` argument when fitting an `OnlineStat`, the output axis is automatically created
  - accessing a static variable (currently only water_mask or country_mask) through `getCubeData` will by default only return the first time step
