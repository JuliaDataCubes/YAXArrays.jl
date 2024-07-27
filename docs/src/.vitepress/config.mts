import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import mathjax3 from "markdown-it-mathjax3";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
  title: "YAXArrays.jl",
  description: "Yet another xarray-like Julia package",
  lastUpdated: true,
  cleanUrls: true,
  outDir: 'REPLACE_ME_DOCUMENTER_VITEPRESS', // This is required for MarkdownVitepress to work correctly...
  ignoreDeadLinks: true,

  markdown: {
    math: true,
    config(md) {
      md.use(tabsMarkdownPlugin),
        md.use(mathjax3)
    },
    theme: {
      light: "github-light",
      dark: "github-dark"
    }
  },
  themeConfig: {
    outline: 'deep',
    // https://vitepress.dev/reference/default-theme-config
    logo: { src: '/logo.png', width: 24, height: 24 },
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Get Started', link: '/get_started' },
      {
        text: 'User Guide',
        items: [
          { text: 'Types', link: '/UserGuide/types' },
          { text: 'Read', link: '/UserGuide/read' },
          { text: 'Write', link: '/UserGuide/write' },
          { text: 'Convert', link: '/UserGuide/convert' },
          { text: 'Create', link: '/UserGuide/create' },
          { text: 'Select', link: '/UserGuide/select' },
          { text: 'Compute', link: '/UserGuide/compute' },
          { text: 'Chunk', link: '/UserGuide/chunk' },
          { text: 'Cache', link: '/UserGuide/cache' },
          { text: 'Group', link: '/UserGuide/group' },
          { text: 'Combine', link: '/UserGuide/combine' },
          { text: 'FAQ', link: '/UserGuide/faq' }
        ]
      },
      {
        text: 'Tutorials',
        items: [
          { text: 'Overview', link: '/tutorials/tutorial' },
          { text: 'Plotting maps', link: '/tutorials/plottingmaps' },
          { text: 'Mean Seasonal Cycle', link: '/tutorials/mean_seasonal_cycle' },
          {
            text: 'ESDL studies',
            items: [
              { text: 'ESDL study 1', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/src/tutorials/esdl/examples_from_esdl_study_1.jl' },
              { text: 'ESDL study 2', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/src/tutorials/esdl/examples_from_esdl_study_2.jl' },
              { text: 'ESDL study 3', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/src/tutorials/esdl/examples_from_esdl_study_3.jl' },
              { text: 'ESDL study 4', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl/blob/master/docs/src/tutorials/esdl/examples_from_esdl_study_4.jl' },
            ]
          },
          { text: 'Other Tutorials', link: '/tutorials/other_tutorials' },
        ]
      },
      { text: 'Ecosystem',
        items: [
          { text: 'DimensionalData.jl', link: 'https://rafaqz.github.io/DimensionalData.jl/dev/' },
          { text: 'NetCDF.jl', link: 'https://juliageo.org/NetCDF.jl/stable/'},
          { text: 'Zarr.jl', link: 'https://juliaio.github.io/Zarr.jl/latest/'},
          { text: 'ArchGDAL.jl', link: 'https://yeesian.com/ArchGDAL.jl/stable/' },
          { text: 'GeoMakie.jl', link: 'https://geo.makie.org/dev/' },
          { text: 'Makie.jl', link: 'https://docs.makie.org/dev/' },
         ]
       },
      {
        text: 'Development',
        items: [
          { text: 'Contribute', link: 'development/contribute' },
          { text: 'Contributors', link: 'development/contributors' }
        ]
      },
    ],

    sidebar: [
      { text: 'Get Started', link: '/get_started' },
      { text: 'API Reference', link: 'api' },
      {
        text: 'User Guide',
        items: [
          { text: 'Types', link: '/UserGuide/types' },
          { text: 'Read', link: '/UserGuide/read' },
          { text: 'Write', link: '/UserGuide/write' },
          { text: 'Convert', link: '/UserGuide/convert' },
          { text: 'Create', link: '/UserGuide/create' },
          { text: 'Select', link: '/UserGuide/select' },
          { text: 'Compute', link: '/UserGuide/compute' },
          { text: 'Chunk', link: '/UserGuide/chunk' },
          { text: 'Cache', link: '/UserGuide/cache' },
          { text: 'Group', link: '/UserGuide/group' },
          { text: 'Combine', link: '/UserGuide/combine' },
          { text: 'FAQ', link: '/UserGuide/faq' }
        ]
      },
      {
        text: 'Tutorials',
        items: [
          { text: 'Plotting maps', link: '/tutorials/plottingmaps' },
          { text: 'Mean Seasonal Cycle', link: '/tutorials/mean_seasonal_cycle' },
          { text: 'Other Tutorials', link: '/tutorials/other_tutorials' },
        ]
      },
      {
        text: 'Development',
        items: [
          { text: 'Contribute', link: 'development/contribute' },
          { text: 'Contributors', link: 'development/contributors' }
        ]
      },
    ],
    editLink: {
      pattern: 'https://github.com/JuliaDataCubes/YAXArrays.jl/edit/master/docs/src/:path'
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://github.com/LuxDL/DocumenterVitepress.jl" target="_blank"><strong>DocumenterVitepress.jl</strong></a>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}. Released under the MIT License.`
    }
  }
})