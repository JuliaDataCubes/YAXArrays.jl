```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "YAXArrays.jl"
  text: "Yet another xarray-like Julia package"
  tagline: NetCDF、Zarr、GDAL などのストアに基づいて、アウトオブコアのラベル付きアレイを操作するためのパッケージ
  image:
    src: /logo.png
    alt: VitePress
  actions:
    - theme: brand
      text: はじめる
      link: /api-examples
    - theme: alt
      text: APIリファレンス
      link: /api-examples
    - theme: alt
      text: Githubで見る
      link: /api-examples

features:
  - title: データ
    details: さまざまなソース (NetCDF、Zarr、ArchGDAL) からのオープン データセット
  - title: 相互運用性
    details: YAXArrayBase を介した他の名前付き軸パッケージとの相互運用性
  - title: 効率
    details: 巨大な複数のアレイに対する効率的な `mapslices(x)` 操作、高レイテンシのデータ アクセス (オブジェクト ストレージ、圧縮データセット) 向けに最適化
---

``` 