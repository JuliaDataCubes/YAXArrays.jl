```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: Un paquete para operar en arreglos etiquetados fuera del núcleo, basado en tiendas como NetCDF, Zarr o GDAL
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: Empezando
      link: /api-examples
    - theme: alt
      text: Referencia API
      link: /api-examples
    - theme: alt
      text: Ver en Github
      link: /api-examples

features:
  - title: Datos
    details: Conjuntos de datos abiertos de una variedad de fuentes (NetCDF, Zarr, ArchGDAL)
  - title: Interoperabilidad
    details: Interoperabilidad con otros paquetes de ejes con nombre a través de YAXArrayBase
  - title: Eficiencia
    details: Operaciones eficientes de `mapslices(x)` en enormes matrices múltiples, optimizadas para acceso a datos de alta latencia (almacenamiento de objetos, conjuntos de datos comprimidos)
---

``` 