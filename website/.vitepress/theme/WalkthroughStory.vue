<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { withBase } from 'vitepress';
import { scenes } from './walkthrough-scenes.mjs';

const figures = ref([]);
const seen = ref(new Set());
let observer;
onMounted(() => {
  if (!('IntersectionObserver' in window)) return;
  observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      seen.value = new Set([...seen.value, entry.target.dataset.scene]);
      observer.unobserve(entry.target);
    }
  }, { threshold: 0.35 });
  figures.value.forEach(figure => observer.observe(figure));
});
onBeforeUnmount(() => observer?.disconnect());

const records = [
  { label: 'Command accepted', detail: 'update-042' },
  { label: 'Tests passed', detail: 'Saved by the server' },
  { label: 'Outcome uncertain', detail: 'Pull request not confirmed' }
];
</script>

<template>
  <div class="walkthrough-story">
    <div class="story-request">
      <p class="request-label">One task</p>
      <p class="request-text">Update a dependency, run the tests, and open a pull request.</p>
      <p class="request-context">An illustrated example. The agent is the actor; the DASP server keeps its session history.</p>
    </div>

    <section v-for="(scene, i) in scenes" :key="scene.id" class="story-step" :aria-labelledby="scene.id">
      <div class="step-number" aria-hidden="true">{{ i + 1 }}</div>
      <div class="step-content">
        <h2 :id="scene.id">{{ scene.title }}</h2>
        <div class="step-layout">
          <div class="step-copy">
            <p>{{ scene.text }}</p>
            <p class="step-benefit"><span>DASP’s rule</span>{{ scene.benefit }}</p>
          </div>

          <figure :ref="el => { if (el) figures[i] = el; }" :data-scene="scene.id" class="step-figure" :class="{ 'has-entered': seen.has(scene.id) }">
            <div v-if="i === 0" class="exchange lost-exchange">
              <div><strong>Your app</strong><span class="warning">Reply lost</span></div>
              <div class="message-path broken-path" aria-hidden="true"><span class="message-dot"></span><span class="break-mark">×</span></div>
              <div><strong>Server</strong><span>Work continues</span></div>
            </div>
            <div v-else-if="i === 1" class="retry-attempts">
              <div><span>First attempt</span><code>update-042</code></div>
              <div class="repeated-attempt"><span>Retry · same input</span><code>update-042</code></div>
              <p class="retry-result"><span aria-hidden="true">↓</span> One accepted command</p>
            </div>
            <div v-else-if="i === 2" class="shared-clients">
              <div><strong>Your app</strong><span>Applied through 0</span><div class="read-position" aria-hidden="true"><b>0</b><span class="empty-position">1</span><span class="empty-position">2</span></div></div>
              <div><strong>Teammate’s CLI</strong><span>Applied through 2</span><div class="read-position" aria-hidden="true"><span>0</span><span class="applied-position">1</span><b>2</b></div></div>
            </div>
            <div v-else class="exchange external-exchange">
              <div><strong>Git provider</strong><span>Did it create the PR?</span></div>
              <div class="message-path broken-path" aria-hidden="true"><span class="message-dot"></span><span class="break-mark">?</span></div>
              <div><strong>Result</strong><span class="warning">Unconfirmed</span></div>
            </div>

            <div class="server-record">
              <div class="record-heading"><strong>DASP server</strong><span>{{ i === 3 ? 'After restart' : 'Saved history' }}</span></div>
              <ol :aria-label="`Saved history: ${scene.title}`">
                <li v-for="(record, index) in records.slice(0, scene.count)" :key="record.label" :class="{ 'uncertain-record': index === 2 }">
                  <span class="record-number">{{ index + 1 }}</span>
                  <div><strong>{{ record.label }}</strong><span>{{ record.detail }}</span></div>
                  <svg v-if="index < 2" viewBox="0 0 16 16" aria-hidden="true"><path d="M3 8L6 11L13 4" /></svg>
                  <span v-else class="uncertain-mark" aria-hidden="true">?</span>
                </li>
              </ol>
            </div>
            <figcaption>{{ scene.caption }}</figcaption>
          </figure>
        </div>

        <details class="message-details">
          <summary>See the protocol details<span class="sr-only">: {{ scene.title }}</span></summary>
          <p>{{ scene.messageNote }}</p>
          <a :href="withBase(scene.rule)">{{ scene.ruleLabel }} →</a>
          <pre tabindex="0" :aria-label="`CloudEvents: ${scene.title}`"><code>{{ JSON.stringify(scene.messages, null, 2) }}</code></pre>
        </details>
      </div>
    </section>
  </div>
</template>

<style scoped>
.walkthrough-story { container-type: inline-size; margin: 32px 0 40px; }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; border: 0; }
.story-request { padding: 22px 26px; border-left: 3px solid var(--vp-c-brand-1); background: var(--vp-c-bg-soft); }
.story-request p { margin: 0; }
.story-request .request-label { font-size: 12px; font-weight: 650; color: var(--vp-c-brand-1); }
.story-request .request-text { margin-top: 5px; font-size: 19px; font-weight: 550; line-height: 1.5; text-wrap: balance; }
.story-request .request-context { margin-top: 10px; font-size: 13px; color: var(--vp-c-text-2); line-height: 1.6; }
.story-step { position: relative; display: grid; grid-template-columns: 32px minmax(0, 1fr); column-gap: 20px; padding-top: 40px; }
.story-step:not(:last-child)::before { content: ''; position: absolute; left: 15px; top: 73px; bottom: -39px; border-left: 1px solid var(--vp-c-divider); }
.step-number { display: grid; place-items: center; width: 32px; height: 32px; border: 1px solid var(--vp-c-brand-1); border-radius: 50%; color: var(--vp-c-brand-1); font-size: 14px; font-weight: 550; font-variant-numeric: tabular-nums; background: var(--vp-c-bg); }
.walkthrough-story .story-step h2 { margin: 0 0 22px; padding: 0; border: 0; font-size: 25px; line-height: 1.3; letter-spacing: -.025em; scroll-margin-top: 128px; }
.step-layout { display: grid; grid-template-columns: minmax(0, .95fr) minmax(0, 1.05fr); gap: 32px; align-items: start; }
.step-copy > p { font-size: 15px; margin: 0; }
.step-copy .step-benefit { margin-top: 24px; color: var(--vp-c-text-1); font-size: 14px; }
.step-benefit > span { display: block; margin-bottom: 5px; font-size: 12px; font-weight: 650; color: var(--vp-c-brand-1); }
.step-figure { min-width: 0; margin: 0; padding: 20px; background: var(--vp-c-bg-soft); border-radius: 6px; }
.exchange { display: grid; grid-template-columns: auto minmax(24px, 1fr) auto; align-items: center; gap: 10px; margin: 0 0 20px; }
.exchange strong, .shared-clients strong { display: block; font-size: 13px; font-weight: 600; }
.exchange > div > span, .shared-clients > div > span { display: block; font-size: 11px; color: var(--vp-c-text-2); }
.exchange > div > .warning { color: var(--dasp-warning); }
.message-path { position: relative; height: 1px; background: var(--dasp-line); }
.broken-path { background: none; border-top: 1px dashed var(--dasp-line); }
.message-path .break-mark { position: absolute; top: -13px; left: calc(50% - 10px); width: 20px; text-align: center; line-height: 24px; background: var(--vp-c-bg-soft); font-size: 16px; color: var(--dasp-warning); }
.message-path .message-dot { position: absolute; right: 0; top: -3px; width: 6px; height: 6px; border-radius: 50%; background: var(--vp-c-brand-1); opacity: 0; }
.retry-attempts { margin-bottom: 14px; }
.retry-attempts > div { display: flex; flex-wrap: wrap; justify-content: space-between; column-gap: 12px; padding: 5px 0; font-size: 12px; }
.retry-attempts code { padding: 0; background: none; font-size: 12px; color: var(--vp-c-brand-1); }
.retry-attempts .retry-result { margin: 7px 0 0; text-align: center; font-size: 12px; color: var(--vp-c-brand-1); }
.retry-result > span { margin-right: 5px; }
.shared-clients { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 20px; }
.read-position { display: flex; align-items: center; gap: 7px; margin-top: 10px; }
.read-position > * { display: grid; place-items: center; width: 24px; height: 24px; border: 1px solid var(--vp-c-divider); border-radius: 50%; font-family: var(--vp-font-family-mono); font-size: 11px; font-weight: 400; }
.read-position b { background: var(--vp-c-brand-1); border-color: var(--vp-c-brand-1); color: var(--vp-c-bg); }
.read-position .applied-position { color: var(--vp-c-brand-1); border-color: var(--vp-c-brand-1); }
.read-position .empty-position { border-style: dashed; color: var(--vp-c-text-2); }
.server-record { padding: 14px; border: 1px solid var(--dasp-line); background: var(--vp-c-bg); border-radius: 4px; }
.record-heading { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 3px 10px; padding-bottom: 9px; border-bottom: 1px solid var(--vp-c-divider); }
.record-heading strong { font-size: 13px; font-weight: 600; color: var(--vp-c-brand-1); }
.record-heading > span { font-size: 11px; color: var(--vp-c-text-2); }
.server-record ol { list-style: none; padding: 0; margin: 12px 0 0; }
.server-record li { display: flex; align-items: center; gap: 10px; margin: 0; padding: 5px 0; }
.record-number { font-family: var(--vp-font-family-mono); font-size: 11px; color: var(--vp-c-text-2); }
.server-record li > div { flex: 1; min-width: 0; }
.server-record li strong { display: block; font-size: 13px; line-height: 1.5; font-weight: 550; }
.server-record li div > span { display: block; color: var(--vp-c-text-2); font-size: 11px; line-height: 1.6; }
.server-record li svg { flex: 0 0 14px; width: 14px; height: 14px; fill: none; stroke: var(--vp-c-brand-1); stroke-width: 1.5; }
.uncertain-record strong, .uncertain-mark { color: var(--dasp-warning); }
.uncertain-mark { width: 14px; text-align: center; }
.step-figure figcaption { margin-top: 12px; font-size: 12px; line-height: 1.6; color: var(--vp-c-text-2); }
.message-details { margin-top: 18px; border-bottom: 1px solid var(--vp-c-divider); padding-bottom: 20px; }
.message-details summary { width: fit-content; padding: 8px 0; cursor: pointer; font-size: 13px; color: var(--vp-c-text-2); }
.message-details summary:hover { color: var(--vp-c-brand-1); }
.message-details summary:focus-visible, .message-details pre:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 4px; }
.message-details p, .message-details a { font-size: 14px; }
.message-details pre { overflow: auto; max-height: 420px; padding: 18px; background: var(--vp-c-bg-soft); border-radius: 4px; line-height: 1.8; }
.message-details pre code { background: none; padding: 0; color: var(--vp-c-text-1); font-size: 12px; }
@media (prefers-reduced-motion: no-preference) {
  .has-entered .message-dot { animation: reply-lost 850ms ease-out both; }
  .has-entered .external-exchange .message-dot { animation-name: external-reply-lost; }
  .has-entered .repeated-attempt { animation: same-command 900ms ease-out both; }
  .has-entered .applied-position { animation: fact-applied 750ms ease-out both; }
  .has-entered .uncertain-record { animation: fact-applied 750ms ease-out both; }
}
@keyframes reply-lost { 0% { right: 0; opacity: 0; } 20% { opacity: 1; } 100% { right: 50%; opacity: 0; } }
@keyframes external-reply-lost { 0% { right: 100%; opacity: 0; } 20% { opacity: 1; } 100% { right: 50%; opacity: 0; } }
@keyframes same-command { 0% { background: var(--vp-c-brand-soft); } 100% { background: transparent; } }
@keyframes fact-applied { 0% { background: var(--vp-c-brand-soft); } 100% { background: transparent; } }
@container (max-width: 680px) {
  .step-layout { grid-template-columns: 1fr; gap: 20px; }
  .step-copy .step-benefit { margin-top: 16px; }
  .step-figure { max-width: 440px; width: 100%; }
}
@container (max-width: 440px) {
  .story-request { padding: 18px; }
  .story-request .request-text { font-size: 17px; }
  .story-step { column-gap: 12px; grid-template-columns: 26px minmax(0, 1fr); padding-top: 32px; }
  .step-number { width: 26px; height: 26px; font-size: 12px; }
  .story-step:not(:last-child)::before { left: 12px; top: 59px; bottom: -31px; }
  .walkthrough-story .story-step h2 { font-size: 23px; margin-bottom: 16px; }
  .step-figure { padding: 14px; }
  .exchange { gap: 6px; }
  .external-exchange { grid-template-columns: 1fr; gap: 8px; }
  .external-exchange .message-path { width: 50%; margin: 8px 0; }
  .shared-clients { gap: 8px; }
  .shared-clients strong { font-size: 12px; }
  .read-position { gap: 5px; }
}
</style>
