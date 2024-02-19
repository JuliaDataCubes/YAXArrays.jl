import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import mathjax3 from "markdown-it-mathjax3";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: 'REPLACE_ME_WITH_DOCUMENTER_VITEPRESS_BASE_URL_WITH_TRAILING_SLASH',
  title: "YAXArrays.jl",
  description: "Yet another xarray-like Julia package",
  lastUpdated: true,
  cleanUrls: true,
  ignoreDeadLinks: true,
  
  markdown: {
    math: true,
    config(md) {
      md.use(tabsMarkdownPlugin),
      md.use(mathjax3)
    },
    theme: {
      light: "github-light",
      dark: "github-dark"}
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
      { text: 'Getting Started', link: '/getting_started' },
      { text: 'User Guide',
        items: [
          { text: 'Creating YAXArrays and Datasets', link: '/UserGuide/creating' },
          { text: 'Indexing and subsetting', link: '/UserGuide/indexing_subsetting' },
          { text: 'Saving YAXArrays and Datasets', link: '/UserGuide/saving' },
          { text: 'Setting chunks size', link: '/UserGuide/setchuncks' },
          { text: 'Apply functions on YAXArrays', link: '/UserGuide/applyfunctions' },
          { text: 'Create Cube from function', link: '/UserGuide/create_cube_from_function' },
          { text: 'Distributed computing', link: '/UserGuide/distributed' },
          { text: 'Open NetCDF', link: '/UserGuide/openNetCDF' },
          { text: 'Open Zarr (Store)', link: '/UserGuide/openZarr' },
      ]},
      { text: 'Tutorials',
        items: [
          { text: 'Overview', link: '/tutorials/tutorial' },
          { text: 'Plotting maps', link: '/tutorials/plottingmaps' },
          { text: 'Mean Seasonal Cycle', link: '/tutorials/mean_seasonal_cycle' },
          { text: 'ESDL study 3', link: '/tutorials/examples_from_esdl_study_3' },
          { text: 'ESDL study 4', link: '/tutorials/examples_from_esdl_study_4' },
      ]},
      { text: 'How do I?',
      items: [
        { text: 'How do I ...', link: '/HowdoI/howdoi' },
        { text: 'Contribute to docs', link: '/HowdoI/contribute' }
    ]},
    ],

    sidebar: [
      { text: 'Getting Started', link: '/getting_started' },
      { text: 'User Guide',
        items: [
          { text: 'Creating YAXArrays and Datasets', link: '/UserGuide/creating' },
          { text: 'Indexing and subsetting', link: '/UserGuide/indexing_subsetting' },
          { text: 'Saving YAXArrays and Datasets', link: '/UserGuide/saving' },
          { text: 'Setting chunks size', link: '/UserGuide/setchuncks' },
          { text: 'Apply functions on YAXArrays', link: '/UserGuide/applyfunctions' },
          { text: 'Create Cube from function', link: '/UserGuide/create_cube_from_function' },
          { text: 'Distributed computing', link: '/UserGuide/distributed' },
          { text: 'Open NetCDF', link: '/UserGuide/openNetCDF' },
          { text: 'Open Zarr (Store)', link: '/UserGuide/openZarr' },
      ]},
      { text: 'Tutorials',
        items: [
          { text: 'Overview', link: '/tutorials/tutorial' },
          { text: 'Plotting maps', link: '/tutorials/plottingmaps' },
          { text: 'Mean Seasonal Cycle', link: '/tutorials/mean_seasonal_cycle' },
          { text: 'ESDL study 3', link: '/tutorials/examples_from_esdl_study_3' },
          { text: 'ESDL study 4', link: '/tutorials/examples_from_esdl_study_4' },
      ]},
      { text: 'How do I?',
      items: [
        { text: 'How do I ...', link: '/HowdoI/howdoi' },
        { text: 'Contribute to docs', link: '/HowdoI/contribute' }
    ]},
    { text: 'API',
    items: [
      { text: 'API Reference', link: 'api' },
    ]},
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/JuliaDataCubes/YAXArrays.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://github.com/LuxDL/DocumenterVitepress.jl" target="_blank"><strong>DocumenterVitepress.jl</strong></a> by <a href="https://github.com/lazarusA" target="_blank"><strong>Lazaro Alonso</strong><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}. Released under the MIT License.`
    }
  }
})