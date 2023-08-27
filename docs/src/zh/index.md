```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: 用于在核外标记阵列上运行的软件包，基于 NetCDF、Zarr 或 GDAL 等商店
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: 入门
      link: /api-examples
    - theme: alt
      text: API参考
      link: /api-examples
    - theme: alt
      text: 在Github上查看
      link: /api-examples

features:
  - title: 数据
    details: 来自各种来源的开放数据集（NetCDF、Zarr、ArchGDAL）
  - title: 互操作性
    details: 通过 YAXArrayBase 与其他命名轴包进行互操作
  - title: 效率
    details: 对大型多个数组进行高效的“mapslices(x)”操作，针对高延迟数据访问（对象存储、压缩数据集）进行了优化
---

``` 