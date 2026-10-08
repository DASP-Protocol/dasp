<script setup>
import { ref } from 'vue';
import { withBase } from 'vitepress';
const panel = ref(null);
function close() {
  if (!panel.value?.open) return;
  panel.value.open = false;
  panel.value.querySelector('summary')?.focus();
}
</script>
<template>
  <details ref="panel" class="cloudevents-help" @keydown.esc.stop="close">
    <summary>CloudEvents <span aria-hidden="true">ⓘ</span><span class="sr-only">: what is this message format?</span></summary>
    <div class="help-content">
      <p>CloudEvents is an open, widely used standard for event messages. DASP uses its common envelope for event identity, source, type, and data. DASP adds the session and recovery rules.</p>
      <a :href="withBase('/guide/cloudevents.html')">Why DASP uses CloudEvents →</a>
    </div>
  </details>
</template>
<style scoped>
.cloudevents-help { margin: 10px 0; font-size: 13px; }
summary { cursor: pointer; color: var(--vp-c-brand-1); width: fit-content; padding: 4px 0; }
summary:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }
.help-content { padding: 12px 16px; margin-top: 6px; background: var(--vp-c-bg-soft); border-left: 2px solid var(--vp-c-brand-1); max-width: 560px; }
.help-content p { margin: 0 0 8px; font-size: 13px; line-height: 1.7; }
.help-content a { text-decoration: underline; text-underline-offset: 3px; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0,0,0,0); white-space: nowrap; }
</style>
