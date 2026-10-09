# Changelog

## Unreleased

- Support variable-length element types (e.g. `String`) in `savecube`/`savedataset` by no
  longer requiring a definite `sizeof` for the element type; sizes come from
  `DiskArrays.element_size`, which from DiskArrays 0.4.25 also accepts an element type
- `savecube`/`savedataset` (`copy_diskarray`) run an incremental `GC.gc(false)` instead
  of a full `GC.gc()` after every copied block: a full collection marks every live
  reference, so its cost scaled with the size of a cube of boxed elements (e.g. `String`)
  held in memory and was paid once per block
- `savecube`/`savedataset` of an in-memory array copy it in blocks that are whole
  multiples of the output chunks (`chunk_aligned_buffer`); the chunk-size optimizer,
  which weighs a read cost the in-memory source does not have, could pick blocks that
  cut chunks, each of which was then read back, decoded, merged and re-encoded for
  every block touching it
- DiskArrayEngine integration
- Removed the ParallelUtilities dependency; `fittable` now uses `Distributed.@distributed` for multi-worker runs. This lifts the transitive DataStructures 0.18 pin (#602).