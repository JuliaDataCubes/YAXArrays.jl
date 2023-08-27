import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "YAXArrays.jl",
  description: "Yet another xarray-like Julia package",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: { src: '/logo.png', width: 24, height: 24 },
    search: {
      provider: 'local'
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/quick_start' },
      { text: 'User Guide',
        items: [
          { text: 'Creating YAXArrays and Datasets', link: '/examples/generated/UserGuide/creating' },
          { text: 'Indexing and subsetting', link: '/examples/generated/UserGuide/indexing_subsetting' },
          { text: 'Saving YAXArrays and Datasets', link: '/examples/generated/UserGuide/saving' },
          { text: 'Setting chunks size', link: '/examples/generated/UserGuide/setchuncks' },
          { text: 'Apply functions on YAXArrays', link: '/examples/generated/UserGuide/applyfunctions' }
      ]},
      { text: 'Tutorial',
        items: [
          { text: 'Overview', link: '/examples/generated/Tutorials/overview' },
          { text: 'Examples from ESDL study 3', link: '/examples/generated/Tutorials/examples_from_esdl_study_3' },
          { text: 'Examples from ESDL study 4', link: '/examples/generated/Tutorials/examples_from_esdl_study_4' },
          { text: 'Plotting: Simple maps', link: '/examples/generated/Tutorials/simplemaps' }
      ]},
      { text: 'How do I?',
      items: [
        { text: 'Overview', link: '/examples/generated/HowdoI/howdoi' },
        { text: 'Open NetCDF', link: '/examples/generated/HowdoI/openNetCDF' },
        { text: 'Open Zarr (Store)', link: '/examples/generated/HowdoI/openZarr' },
        { text: 'Contribute to docs', link: '/examples/generated/HowdoI/contribute' }
    ]},
    ],

    sidebar: [
      {
        text: 'Learning',
        items: [
          { text: 'Getting Started', link: '/quick_start' },
          { text: 'User Guide', link: '/examples/generated/UserGuide/creating' },
          { text: 'Tutorial', link: '/examples/generated/Tutorials/overview' },
          { text: 'How do I?', link: '/examples/generated/HowdoI/howdoi' },
          { text: 'API reference', link: '/api' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
    ]
  },

  locales: {
    root: {
      label: 'English',
      lang: 'en'
    },
    es: {
      label: 'Español',
      lang: 'es', // optional, will be added  as `lang` attribute on `html` tag
      link: '/es/' // default /fr/ -- shows on navbar translations menu, can be external
    },
    de: {
      label: 'Deutsch',
      lang: 'de', // optional, will be added  as `lang` attribute on `html` tag
      link: '/de/' // default /fr/ -- shows on navbar translations menu, can be external
    },
    zh: {
      label: '简化字',
      lang: 'zh', // optional, will be added  as `lang` attribute on `html` tag
      link: '/zh/' // default /fr/ -- shows on navbar translations menu, can be external
    },
    ja: {
      label: '日本語',
      lang: 'ja', // optional, will be added  as `lang` attribute on `html` tag
      link: '/ja/' // default /fr/ -- shows on navbar translations menu, can be external
    }
  }
})
