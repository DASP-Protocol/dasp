import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'DASP',
  description: 'Durable Actor Session Protocol. A server protocol for commands, saved outcomes, and recovery.',
  base: '/dasp/',
  cleanUrls: false,
  lastUpdated: true,
  scrollOffset: { selector: '.draft-ribbon', padding: 128 },
  head: [
    ['script', { async: '', src: 'https://plausible.io/js/pa-Lp3jx0aSJRXiNVrJAMd3l.js' }],
    ['script', {}, 'window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};plausible.init()'],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/dasp/brand/dasp-favicon.svg' }],
    ['link', { rel: 'icon', sizes: '32x32', type: 'image/png', href: '/dasp/brand/dasp-icon-32.png' }],
    ['link', { rel: 'alternate icon', href: '/dasp/brand/dasp-favicon.ico' }],
    ['link', { rel: 'apple-touch-icon', sizes: '180x180', href: '/dasp/brand/dasp-icon-180.png' }],
    ['link', { rel: 'manifest', href: '/dasp/brand/site.webmanifest' }],
    ['meta', { property: 'og:site_name', content: 'DASP' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:image', content: 'https://dasp-protocol.github.io/dasp/brand/dasp-social.png' }],
    ['meta', { property: 'og:image:width', content: '1200' }],
    ['meta', { property: 'og:image:height', content: '630' }],
    ['meta', { property: 'og:image:alt', content: 'DASP — Durable Actor Session Protocol. Commands. Saved outcomes. Recovery.' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:image', content: 'https://dasp-protocol.github.io/dasp/brand/dasp-social.png' }],
    ['meta', { name: 'twitter:image:alt', content: 'DASP — Durable Actor Session Protocol' }],
    ['meta', { name: 'theme-color', content: '#f7f8fa', media: '(prefers-color-scheme: light)' }],
    ['meta', { name: 'theme-color', content: '#151b24', media: '(prefers-color-scheme: dark)' }]
  ],
  transformHead({ pageData }) {
    const path = pageData.frontmatter.canonicalPath?.replace(/^\//, '').split('#')[0] || pageData.relativePath.replace(/index\.md$/, '').replace(/\.md$/, '.html');
    const url = 'https://dasp-protocol.github.io/dasp/' + path;
    const title = pageData.title === 'DASP' ? 'DASP — Durable Actor Session Protocol' : pageData.title + ' | DASP';
    const description = pageData.description || 'A shared contract for commands, saved outcomes, and recovery.';
    return [
      ['link', { rel: 'canonical', href: url }],
      ['meta', { property: 'og:url', content: url }],
      ['meta', { property: 'og:title', content: title }],
      ['meta', { property: 'og:description', content: description }],
      ['meta', { name: 'twitter:title', content: title }],
      ['meta', { name: 'twitter:description', content: description }]
    ];
  },
  themeConfig: {
    logo: { light: '/brand/dasp-mark-light.svg', dark: '/brand/dasp-mark-dark.svg', alt: 'DASP' },
    siteTitle: 'DASP',
    nav: [
      { text: 'Guide', link: '/guide/' },
      { text: 'Build', link: '/build/' },
      { text: 'Specification', link: '/specification/' },
      { text: 'Reference', link: '/reference/' },
      { text: 'About', link: '/about/' }
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/DASP-Protocol/dasp' }],
    search: { provider: 'local' },
    sidebar: {
      '/guide/': [{ text: 'Understand DASP', items: [
        { text: 'How DASP works', link: '/guide/' },
        { text: 'Follow a command', link: '/guide/walkthrough' },
        { text: 'DASP and other protocols', link: '/guide/comparisons' },
        { text: 'Why CloudEvents?', link: '/guide/cloudevents' }
      ]}],
      '/build/': [{ text: 'Build with DASP', items: [
        { text: 'Start building', link: '/build/' },
        { text: 'Language clients', link: '/build/clients', items: [
          { text: 'Elixir', link: '/build/elixir' },
          { text: 'TypeScript', link: '/build/typescript' }
        ]},
        { text: 'Implement a host', link: '/build/host' },
        { text: 'Define a profile and binding', link: '/build/profiles-and-bindings' }
      ]}],
      '/specification/': [{ text: 'Core draft · draft-01', items: [
        { text: 'Scope and versions', link: '/specification/' },
        { text: 'Sessions and command lifecycle', link: '/specification/model' },
        { text: 'Messages and errors', link: '/specification/messages' },
        { text: 'CloudEvents envelope', link: '/specification/cloudevents' },
        { text: 'Admission and recovery', link: '/specification/recovery' },
        { text: 'Profiles and bindings', link: '/specification/profiles-and-bindings' },
        { text: 'WebSocket live delivery', link: '/specification/websocket-live-delivery' },
        { text: 'Security and compatibility', link: '/specification/security-and-versioning' }
      ]}, { text: 'Binding proposals', items: [
        { text: 'Encrypted CloudEvent delivery', link: '/specification/payload-encryption' },
        { text: 'Proof of authority', link: '/specification/proof-of-authority' }
      ]}, { text: 'Conformance', items: [
        { text: 'What is tested', link: '/specification/conformance/' },
        { text: 'Run the checks', link: '/specification/conformance/running-checks' },
        { text: 'Runtime test cases', link: '/specification/conformance/behavioral-cases' }
      ]}],
      '/reference/': [{ text: 'Reference', items: [
        { text: 'Find an artifact', link: '/reference/' },
        { text: 'Schemas and downloads', link: '/reference/schemas' },
        { text: 'Message examples and traces', link: '/reference/examples' },
        { text: 'Counter profile', link: '/reference/counter' },
        { text: 'Glossary', link: '/reference/glossary' }
      ]}],
      '/about/': [{ text: 'About', items: [
        { text: 'About DASP', link: '/about/' },
        { text: 'Status and open decisions', link: '/about/status' },
        { text: 'Contributing', link: '/about/contributing' },
        { text: 'Changes', link: '/about/changes' },
        { text: 'Security reporting', link: '/about/security' }
      ]}]
    },
    outline: [2, 3],
    footer: { message: 'DASP · Working review draft · <a href="/dasp/about/status.html">Status</a> · <a href="/dasp/about/contributing.html">Contribute</a> · <a href="/dasp/about/releasing.html">Release preparation</a> · <a href="/dasp/brand.html">Brand</a>' }
  }
});
