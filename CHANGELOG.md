# Changelog

## Unreleased

- Support variable-length element types (e.g. `String`) in `savecube`/`savedataset` by no
  longer requiring a definite `sizeof` for the element type
- `savecube`/`savedataset` (`copy_diskarray`) run an incremental `GC.gc(false)` instead
  of a full `GC.gc()` after every copied block: a full collection marks every live
  reference, so its cost scaled with the size of a cube of boxed elements (e.g. `String`)
  held in memory and was paid once per block
- DiskArrayEngine integration
- Removed the ParallelUtilities dependency; `fittable` now uses `Distributed.@distributed` for multi-worker runs. This lifts the transitive DataStructures 0.18 pin (#602).