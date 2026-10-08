<script setup>
import { computed, ref } from 'vue';
import trace from '../../../conformance/fixtures/recovery-trace.json';
import CloudEventsHelp from './CloudEventsHelp.vue';
const event = trace.steps.find(step => step.id === 'command').event;
const selected = ref('envelope');
const groups = [
  { id: 'envelope', label: 'CloudEvents envelope', note: 'Standard attributes identify the event and describe its data. The type value is chosen by DASP.', keys: ['specversion', 'id', 'source', 'type', 'datacontenttype'] },
  { id: 'extension', label: 'DASP extension', note: 'requestid connects one request attempt to its direct reply. A retry uses a new request ID.', keys: ['requestid'] },
  { id: 'body', label: 'DASP message body', note: 'data identifies the session and command. The profile defines counter.add and its amount input.', keys: ['data'] }
];
const group = computed(() => groups.find(item => item.id === selected.value));
const entries = Object.entries(event);
function lines(key, value, index) {
  return `${JSON.stringify(key)}: ${JSON.stringify(value, null, 2)}${index < entries.length - 1 ? ',' : ''}`;
}
</script>
<template>
  <div class="anatomy">
    <div class="groups" role="group" aria-label="Message field groups">
      <button v-for="item in groups" :key="item.id" :aria-pressed="selected === item.id" @click="selected = item.id">{{ item.label }}</button>
    </div>
    <p aria-live="polite" class="field-note">{{ group.note }}</p>
    <CloudEventsHelp />
    <pre tabindex="0" aria-label="Annotated DASP command JSON"><code>{<span v-for="([key, value], i) in entries" :key="key" class="field" :class="{ selected: group.keys.includes(key) }">{{ lines(key, value, i) }}</span>}</code></pre>
  </div>
</template>
<style scoped>
.anatomy { margin: 24px 0; }
.groups { display: flex; flex-wrap: wrap; gap: 8px; }
button { font: inherit; font-size: 13px; padding: 8px 12px; border: 1px solid var(--vp-c-divider); border-radius: 6px; cursor: pointer; }
button[aria-pressed="true"] { background: var(--dasp-button-bg); color: var(--dasp-button-text); }
button:focus-visible, pre:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }
.field-note { min-height: 52px; font-size: 14px; }
pre { overflow-x: auto; padding: 16px; background: var(--vp-c-bg-soft); border-radius: 8px; font-size: 12px; line-height: 1.7; }
.field { display: block; padding: 0 12px; border-left: 2px solid transparent; }
.field.selected { background: var(--vp-c-brand-soft); border-left-color: var(--vp-c-brand-1); }
</style>
