<script setup>
import { ref, computed } from 'vue';
import examples from '../../../specification/draft-01/examples/counter.json';
import CloudEventsHelp from './CloudEventsHelp.vue';
const selected = ref(examples.findIndex(event => event.type === 'dasp.v1.command'));
const event = computed(() => examples[selected.value]);
</script>
<template>
  <div class="message-examples">
    <label for="example-message">Message</label>
    <select id="example-message" v-model="selected">
      <option v-for="(item, index) in examples" :key="item.id" :value="index">{{ item.type }}{{ item.data.kind ? ` · ${item.data.kind}` : '' }}</option>
    </select>
    <CloudEventsHelp />
    <pre tabindex="0" aria-label="Complete example message JSON"><code>{{ JSON.stringify(event, null, 2) }}</code></pre>
  </div>
</template>
<style scoped>
label { display: block; font-size: 13px; font-weight: 600; margin-bottom: 8px; }
select { width: 100%; max-width: 100%; border: 1px solid var(--vp-c-divider); border-radius: 6px; padding: 10px; background: var(--vp-c-bg); color: var(--vp-c-text-1); font: inherit; font-size: 13px; }
select:focus-visible, pre:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }
pre { overflow-x: auto; padding: 20px; background: var(--vp-c-bg-soft); border-radius: 8px; font-size: 12px; line-height: 1.7; max-height: 600px; }
</style>
