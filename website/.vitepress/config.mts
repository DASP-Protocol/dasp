import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'DASP',
  description: 'Durable Actor Session Protocol. A shared contract for commands, outcomes, and recovery.',
  base: '/dasp/',
  cleanUrls: false,
  lastUpdated: true,
  head: [
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
    const path = pageData.relativePath.replace(/index\.md$/, '').replace(/\.md$/, '.html');
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
      { text: 'Protocol', link: '/protocol/' },
      { text: 'Clients', link: '/clients/' },
      { text: 'Conformance', link: '/conformance/' },
      { text: 'Project', link: '/project/decisions' }
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/DASP-Protocol/dasp' }],
    search: { provider: 'local' },
    sidebar: [
      { text: 'Start here', items: [
        { text: 'Introduction', link: '/guide' },
        { text: 'Protocol overview', link: '/protocol/' }
      ]},
      { text: 'The contract', items: [
        { text: 'CloudEvents envelope', link: '/protocol/cloudevents' },
        { text: 'Profiles & bindings', link: '/protocol/profiles-and-bindings' },
        { text: 'Message shapes', link: '/protocol/messages' },
        { text: 'Recovery', link: '/protocol/recovery' },
        { text: 'Security & versions', link: '/protocol/security-and-versioning' },
        { text: 'Examples & fixtures', link: '/protocol/example' }
      ]},
      { text: 'Implement', items: [
        { text: 'Client overview', link: '/clients/' },
        { text: 'Elixir', link: '/clients/elixir' },
        { text: 'TypeScript', link: '/clients/typescript' },
        { text: 'Conformance', link: '/conformance/' }
      ]},
      { text: 'Project', items: [
        { text: 'Brand & assets', link: '/brand' },
        { text: 'Decisions & next steps', link: '/project/decisions' },
        { text: 'Source mapping', link: '/project/seigyo-mapping' },
        { text: 'Seigyo source', link: '/source/' },
        { text: 'Microsoft AHP reference', link: '/project/ahp-reference' }
      ]}
    ],
    outline: [2, 3],
    footer: { message: 'Durable Actor Session Protocol · An open specification in development.' }
  }
});
