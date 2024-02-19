```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: A package for operating on out-of-core labeled arrays, based on stores like NetCDF, Zarr or GDAL
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: Getting Started
      link: /api-examples
    - theme: alt
      text: API reference
      link: /api-examples
    - theme: alt
      text: View on Github
      link: /api-examples

features:
  - title: Data
    details: Open datasets from a variety of sources (NetCDF, Zarr, ArchGDAL).
  - title: Interoperability
    details: Interoperability with other named axis packages through YAXArrayBase.
  - title: Efficiency
    details: Efficient `mapslices(x)` operations on huge multiple arrays, optimized for high-latency data access (object storage, compressed datasets).
---
```