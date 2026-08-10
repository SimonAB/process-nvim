import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'process-nvim',
  description: 'Neovim configuration for research writing and scientific computing',
  base: '/process-nvim/',
  cleanUrls: true,

  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Install', link: '/INSTALLATION_GUIDE' },
      { text: 'Quick Start', link: '/quickstart' },
      {
        text: 'Guides',
        items: [
          { text: 'Media and link peeks', link: '/guide/media-peeks' },
          { text: 'Troubleshooting', link: '/TROUBLESHOOTING_GUIDE' },
          { text: 'Performance', link: '/PERFORMANCE_OPTIMISATIONS' },
          { text: 'LSP Setup', link: '/advanced/lsp-setup' }
        ]
      },
      { text: 'Reference', link: '/reference/keymaps' }
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Quick Start', link: '/quickstart' },
          { text: 'Installation Guide', link: '/INSTALLATION_GUIDE' }
        ]
      },
      {
        text: 'Guides',
        items: [
          { text: 'Media and link peeks', link: '/guide/media-peeks' },
          { text: 'Troubleshooting', link: '/TROUBLESHOOTING_GUIDE' },
          { text: 'Performance Optimisations', link: '/PERFORMANCE_OPTIMISATIONS' }
        ]
      },
      {
        text: 'Reference and Advanced',
        items: [
          { text: 'Keymaps Reference', link: '/reference/keymaps' },
          { text: 'LSP Setup', link: '/advanced/lsp-setup' },
          { text: 'Changelog', link: '/CHANGELOG' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/SimonAB/process-nvim' }
    ],

    search: {
      provider: 'local'
    },

    outline: {
      level: [2, 3],
      label: 'On this page'
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'process-nvim'
    }
  },

  markdown: {
    lineNumbers: true
  },

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/process-nvim/favicon.svg' }]
  ]
})
