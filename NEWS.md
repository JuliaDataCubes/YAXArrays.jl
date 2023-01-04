# News

## v0.4.4
### Added
Add How to sections to the documentation

### Fixed
Fixed subsetting of datasets so that no error is thrown if some of the cubes inside the dataset don't contain the axis for subsetting. 
Fixed batch extraction so that extracted values are not duplicated (#194)
Fixed performance bug in saving of small cubes (#210)
Fix concatenation bug (EarthDataLab # 284)
Fix permutation bug for two input cubes (#201)


## v0.4.3
Added the possibility to use Tables.jl compatible Tables for indexing into a YAXArray. Makes extraction of data from a list of scattered locations in a YAXArray convenient. 

## Unreleased

## v0.3.0

### Fixed
Fix @loadorgenerate ([#134](https://github.com/JuliaDataCubes/YAXArrays.jl/issues/133))


## v0.2.1
### Removed
ByFunction Axis Descriptor (#108)

## v0.2.0

### Added

Allow size with any Axis descriptor (#98)

### Fixed

Allow reduction to single value (#90)

## v0.1.0
