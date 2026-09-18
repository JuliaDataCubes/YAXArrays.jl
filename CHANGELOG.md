# Changelog

## Unreleased

- DiskArrayEngine integration
- Removed the ParallelUtilities dependency; `fittable` now uses `Distributed.@distributed` for multi-worker runs. This lifts the transitive DataStructures 0.18 pin (#602).