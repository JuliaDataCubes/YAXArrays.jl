```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: Ein Paket für den Betrieb auf außerhalb des Kerns gekennzeichneten Arrays, basierend auf Stores wie NetCDF, Zarr oder GDAL
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: Erste Schritte
      link: /api-examples
    - theme: alt
      text: API-Referenz
      link: /api-examples
    - theme: alt
      text: Ansicht auf Github
      link: /api-examples

features:
  - title: Daten
    details: Offene Datensätze aus verschiedenen Quellen (NetCDF, Zarr, ArchGDAL)
  - title: Interoperabilität
    details: Interoperabilität mit anderen benannten Achsenpaketen über YAXArrayBase
  - title: Effizienz
    details: Effiziente `mapslices(x)`-Operationen auf riesigen Mehrfacharrays, optimiert für Datenzugriff mit hoher Latenz (Objektspeicher, komprimierte Datensätze)
---

``` 