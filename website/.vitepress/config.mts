import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'DASP',
  description: 'Durable Actor Session Protocol. A shared contract for commands, outcomes, and recovery.',
  base: '/dasp/',
  cleanUrls: false,
  lastUpdated: true,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/dasp/mark.svg' }],
    ['meta', { name: 'theme-color', content: '#f6f5ef' }]
  ],
  themeConfig: {
    logo: '/mark.svg',
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
        { text: 'Messages & wire format', link: '/protocol/messages' },
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
        { text: 'Decisions & next steps', link: '/project/decisions' },
        { text: 'Seigyo source', link: '/source/' },
        { text: 'Microsoft AHP reference', link: '/project/ahp-reference' }
      ]}
    ],
    outline: [2, 3],
    footer: { message: 'Durable Actor Session Protocol · An open specification in development.' }
  }
});
