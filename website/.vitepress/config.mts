import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'DASP',
  description: 'Durable Actor Session Protocol. A server protocol for commands, saved outcomes, and recovery.',
  base: '/dasp/',
  cleanUrls: false,
  lastUpdated: true,
  scrollOffset: { selector: '.draft-ribbon', padding: 128 },
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
      { text: 'Conformance', link: '/conformance/' },
      { text: 'Reference', link: '/reference/' },
      { text: 'About', link: '/project/about' }
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/DASP-Protocol/dasp' }],
    search: { provider: 'local' },
    sidebar: {
      '/guide/': [{ text: 'Guide', items: [
        { text: 'What is DASP?', link: '/guide/' },
        { text: 'Protocol FAQ', link: '/guide/faq' },
        { text: 'Core concepts', link: '/guide/concepts' },
        { text: 'Use cases', link: '/guide/use-cases' },
        { text: 'Add DASP to a project', link: '/build/' }
      ]}],
      '/build/': [{ text: 'Build with DASP', items: [
        { text: 'Add DASP to your project', link: '/build/' },
        { text: 'Illustrated walkthrough', link: '/build/walkthrough' },
        { text: 'Language clients', link: '/build/clients' },
        { text: 'Elixir package', link: '/build/elixir' },
        { text: 'TypeScript package', link: '/build/typescript' },
        { text: 'Conformance coverage', link: '/conformance/' }
      ]}],
      '/specification/': [{ text: 'Core draft · draft-01', items: [
        { text: 'Status and conventions', link: '/specification/' },
        { text: 'Model and lifecycle', link: '/specification/model' },
        { text: 'CloudEvents envelope', link: '/specification/cloudevents' },
        { text: 'Messages and errors', link: '/specification/messages' },
        { text: 'Admission and recovery', link: '/specification/recovery' },
        { text: 'Profiles and bindings', link: '/specification/profiles-and-bindings' },
        { text: 'Security and versions', link: '/specification/security-and-versioning' }
      ]}],
      '/conformance/': [{ text: 'Conformance', items: [
        { text: 'Scope and coverage', link: '/conformance/' },
        { text: 'Run the checks', link: '/conformance/running-checks' },
        { text: 'Behavioral cases', link: '/conformance/behavioral-cases' }
      ]}],
      '/reference/': [{ text: 'Technical reference', items: [
        { text: 'Reference index', link: '/reference/' },
        { text: 'Schemas and downloads', link: '/reference/schemas' },
        { text: 'Examples and traces', link: '/reference/examples' },
        { text: 'Recorded command exchange', link: '/reference/recorded-exchange' },
        { text: 'Counter profile', link: '/reference/counter' },
        { text: 'Glossary', link: '/reference/glossary' }
      ]}],
      '/project/': [{ text: 'Project', items: [
        { text: 'About DASP', link: '/project/about' },
        { text: 'Review questions', link: '/project/feedback' },
        { text: 'Release preparation', link: '/project/releases' },
        { text: 'Contributing', link: '/project/contributing' },
        { text: 'Security', link: '/project/security' },
        { text: 'Changes', link: '/project/changes' },
        { text: 'Brand and assets', link: '/brand' }
      ]}]
    },
    outline: [2, 3],
    footer: { message: 'DASP · Working review draft · <a href="/dasp/project/about.html">About</a> · <a href="/dasp/project/feedback.html">Review questions</a> · <a href="/dasp/project/releases.html">Releases</a>' }
  }
});
