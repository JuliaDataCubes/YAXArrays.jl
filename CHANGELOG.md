# Changelog

## Unreleased

- Support variable-length element types (e.g. `String`) in `savecube`/`savedataset` by no
  longer requiring a definite `sizeof` for the element type
- DiskArrayEngine integration
- Removed the ParallelUtilities dependency; `fittable` now uses `Distributed.@distributed` for multi-worker runs. This lifts the transitive DataStructures 0.18 pin (#602).