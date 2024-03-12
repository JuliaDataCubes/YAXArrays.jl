```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: A package for operating on out-of-core labeled arrays, based on stores like NetCDF, Zarr or GDAL.
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: Getting Started
      link: /getting_started
    - theme: alt
      text: View on Github
      link: https://github.com/JuliaDataCubes/YAXArrays.jl
    - theme: alt
      text: API reference
      link: /api

features:
  - title: Flexible I/O capabilities
    details: Open and operate on <font color="#D27D2D">NetCDF</font> and <font color="#D27D2D">Zarr</font> datasets directly. Or bring in data from other sources with ArchGDAL.jl, GRIBDatasets.jl, GeoJSON.jl, HDF5.jl, Shapefile.jl, GeoParquet.jl, etc.
    link: /UserGuide/openZarr
  - title: Interoperability
    details: Well integrated with Julia's ecosystem, i.e., distributed operations are native. And plotting with <font color="#D27D2D">Makie.jl</font> is well supported.
  - title: Named dimensions and GroupBy(in memory)
    details: Apply operations over named dimensions, select values by labels and integers as well as efficient split-apply-combine operations with <font color="#D27D2D">groupby</font> via DimensionalData.jl.
    link: /UserGuide/group_by
  - title: Efficiency
    details: Efficient <font color="#D27D2D">mapslices(x) </font> and <font color="#D27D2D">mapCube</font> operations on huge multiple arrays, optimized for high-latency data access (object storage, compressed datasets).
```