<script setup>
import DefaultTheme from 'vitepress/theme';
const { Layout } = DefaultTheme;
</script>

<template>
  <Layout>
    <template #layout-top>
      <aside class="draft-ribbon" aria-label="Draft status">
        <span>Draft for feedback</span>
        <a href="https://github.com/DASP-Protocol/dasp/issues">Share feedback on GitHub <span aria-hidden="true">↗</span></a>
      </aside>
    </template>
  </Layout>
</template>

<style scoped>
.draft-ribbon {
  position: fixed;
  inset: 0 0 auto;
  z-index: var(--vp-z-index-layout-top);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
  height: var(--vp-layout-top-height);
  padding: 4px 16px;
  border-bottom: 1px solid var(--vp-c-divider);
  background: var(--dasp-positive-bg);
  color: var(--vp-c-text-1);
  font-size: 12px;
  line-height: 20px;
}
.draft-ribbon > span { font-weight: 600; }
.draft-ribbon a { color: var(--dasp-positive-text); text-decoration: underline; text-underline-offset: 3px; }
.draft-ribbon a:hover { color: var(--vp-c-text-1); }
.draft-ribbon a:focus-visible { outline-offset: 3px; }
@media (max-width: 480px) {
  .draft-ribbon { flex-direction: column; gap: 0; }
}
</style>
