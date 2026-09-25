<script setup>
import { computed, nextTick, ref } from 'vue';
import { withBase } from 'vitepress';
import ArrowIcon from './ArrowIcon.vue';
import { scenes } from './walkthrough-scenes.mjs';
const active = ref(0);
const tabs = ref([]);
const sceneNavigation = ref(null);
const scenePanel = ref(null);
const scene = computed(() => scenes[active.value]);
const records = [
  { sequence: 1, label: 'Command admitted', detail: 'update-042' },
  { sequence: 2, label: 'Tests passed', detail: 'Application fact' },
  { sequence: 3, label: 'Outcome: uncertain', detail: 'External result unconfirmed' }
];
const saved = computed(() => records.slice(0, scene.value.count));
async function select(index, focus = false) {
  active.value = Math.max(0, Math.min(scenes.length - 1, index));
  if (focus) { await nextTick(); tabs.value[active.value]?.focus(); }
}
function navigate(event) {
  const actions = { ArrowRight: active.value + 1, ArrowLeft: active.value - 1, Home: 0, End: scenes.length - 1 };
  if (event.key in actions) { event.preventDefault(); select(actions[event.key], true); }
}
async function advance(index) {
  await select(index);
  await nextTick();
  scenePanel.value?.focus({ preventScroll: true });
  sceneNavigation.value?.scrollIntoView({
    block: 'start',
    behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth'
  });
}
</script>

<template>
  <section class="walkthrough-story" aria-labelledby="story-title">
    <div class="story-introduction">
      <h2 id="story-title">One command. Six moments that matter.</h2>
      <p>Step through an illustrated sequence. No server runs on this page.</p>
    </div>
    <div ref="sceneNavigation" class="scene-tabs" role="tablist" aria-label="Walkthrough scenes" @keydown="navigate">
      <button v-for="(item, i) in scenes" :id="`story-tab-${i}`" :key="item.label" :ref="el => tabs[i] = el" type="button" role="tab" :aria-selected="active === i" :tabindex="active === i ? 0 : -1" aria-controls="story-scene" @click="select(i)">
        <span class="scene-number">{{ i + 1 }}</span>{{ item.label }}
      </button>
    </div>
    <div id="story-scene" ref="scenePanel" class="scene-panel" role="tabpanel" :aria-labelledby="`story-tab-${active}`" tabindex="0">
      <figure class="story-figure" :data-scene="active">
        <div class="story-identity"><span>Application command <code>dependency.update</code></span><span>Command ID <code>update-042</code></span></div>
        <div class="story-network">
          <div class="story-clients">
            <div class="story-client" :class="{ offline: active === 1 }">
              <svg viewBox="0 0 28 24" aria-hidden="true"><rect x="2" y="2" width="24" height="20" rx="3"/><path d="M2 8H26M6 5H7M10 5H11"/></svg>
              <strong>Web app</strong><span>{{ scene.browser }}</span>
            </div>
            <div class="story-client cli-client" :class="{ waiting: active < 3 }">
              <svg viewBox="0 0 28 24" aria-hidden="true"><rect x="2" y="2" width="24" height="20" rx="3"/><path d="M7 8L11 12L7 16M15 16H21"/></svg>
              <strong>CLI</strong><span>{{ scene.cli }}</span>
            </div>
          </div>
          <div class="story-wire client-wire" :class="{ disconnected: active === 1 }" aria-hidden="true">
            <span v-if="active !== 1 && active !== 4" :key="active" class="message-packet" :class="{ returning: active >= 3 }"></span>
            <span v-if="active === 0" class="message-packet lost-receipt"></span>
            <svg v-if="active === 1" viewBox="0 0 16 16"><path d="M4 4L12 12M12 4L4 12"/></svg>
          </div>
          <div class="story-server" :class="{ checking: active === 4 }">
            <div class="server-heading"><strong>DASP server</strong><span>{{ scene.state }}</span></div>
            <p class="server-actor">Actor: dependency agent</p>
            <TransitionGroup name="saved-record" tag="ol" class="saved-records" aria-label="Saved session updates">
              <li v-for="record in saved" :key="record.sequence" :class="{ uncertain: record.sequence === 3 }"><span class="record-sequence">{{ record.sequence }}</span><div><strong>{{ record.label }}</strong><span>{{ record.detail }}</span></div></li>
            </TransitionGroup>
            <p class="server-retention">Saved across a process restart</p>
          </div>
          <div class="story-wire tool-wire" :class="{ disconnected: active >= 4 }" aria-hidden="true"><span v-if="active === 4" :key="active" class="message-packet lost-packet"></span></div>
          <div class="external-service" :class="{ unknown: active >= 4 }"><svg viewBox="0 0 28 28" aria-hidden="true"><circle cx="7" cy="5" r="3"/><circle cx="21" cy="8" r="3"/><circle cx="7" cy="23" r="3"/><path d="M7 8V20M21 11V14Q21 19 16 19H7"/></svg><strong>Git provider</strong><span>{{ scene.tool }}</span><small>External effect</small></div>
        </div>
        <figcaption>{{ scene.caption }}</figcaption>
      </figure>
      <div class="scene-explanation">
        <h3>{{ scene.title }}</h3>
        <p>{{ scene.text }}</p>
        <dl class="scene-evidence"><div><dt>What the client knows</dt><dd>{{ scene.clientKnows }}</dd></div><div><dt>What the server keeps</dt><dd>{{ scene.serverKeeps }}</dd></div></dl>
        <p class="story-lesson">{{ scene.lesson }}</p>
        <details :key="active" class="message-details"><summary>Inspect the messages and the rule</summary><p>{{ scene.messageNote }}</p><p><a :href="withBase(scene.rule)">{{ scene.ruleLabel }} <ArrowIcon :size="14" /></a></p><pre tabindex="0" aria-label="Illustrative CloudEvents messages"><code>{{ JSON.stringify(scene.messages, null, 2) }}</code></pre></details>
      </div>
    </div>
    <div class="scene-navigation"><button type="button" :disabled="active === 0" @click="advance(active - 1)"><ArrowIcon class="previous-arrow" :size="16" /> Previous scene</button><span aria-live="polite" aria-atomic="true">Scene {{ active + 1 }} of {{ scenes.length }}<span class="sr-only">: {{ scene.label }}</span></span><button v-if="active < scenes.length - 1" class="next-scene" type="button" @click="advance(active + 1)">Next: {{ scenes[active + 1].label }} <ArrowIcon :size="16" /></button><button v-else class="next-scene" type="button" @click="advance(0)">Read from the start <ArrowIcon :size="16" /></button></div>
    <p class="story-scope">The dependency command and tool behavior are illustrative. A released application profile and DASP server are not provided.</p>
  </section>
</template>

<style scoped>
.walkthrough-story { margin: 36px 0 48px; }
.walkthrough-story .story-introduction h2 { margin: 0 0 8px; font-size: 25px; line-height: 1.3; }
.walkthrough-story .story-introduction p { margin: 0 0 24px; font-size: 14px; color: var(--vp-c-text-2); }
.scene-tabs { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); border-bottom: 1px solid var(--vp-c-divider); scroll-margin-top: 112px; }
.scene-tabs button { display: flex; flex-direction: column; gap: 5px; align-items: flex-start; min-height: 68px; padding: 10px 8px 13px; border-bottom: 2px solid transparent; font-size: 13px; font-weight: 550; color: var(--vp-c-text-2); }
.scene-tabs button:hover { background: var(--vp-c-brand-soft); color: var(--vp-c-text-1); }
.scene-tabs button[aria-selected="true"] { border-color: var(--vp-c-brand-1); color: var(--vp-c-brand-1); background: var(--vp-c-brand-soft); }
.scene-number { font-size: 12px; font-variant-numeric: tabular-nums; }
.scene-panel { outline-offset: 5px; }
.scene-panel:focus-visible { outline: 2px solid var(--vp-c-brand-1); }
.story-figure { margin: 0; padding: 24px; background: var(--vp-c-bg-soft); }
.story-identity { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 6px 20px; color: var(--vp-c-text-2); font-size: 11px; line-height: 1.8; }
.story-identity code { font-size: 11px; background: none; color: var(--vp-c-text-1); padding: 0 0 0 4px; }
.story-network { display: grid; grid-template-columns: 108px 56px minmax(210px, 1fr) 48px 104px; align-items: center; margin: 25px 0 20px; }
.story-clients { display: flex; flex-direction: column; gap: 22px; }
.story-client, .external-service { display: flex; flex-direction: column; align-items: flex-start; gap: 5px; font-size: 12px; line-height: 1.5; }
.story-client strong, .external-service strong { font-size: 14px; font-weight: 600; }
.story-client > span, .external-service > span { color: var(--vp-c-text-2); }
.story-client > svg, .external-service > svg { width: 25px; height: 25px; margin-bottom: 3px; stroke: var(--dasp-line); fill: none; stroke-width: 1.5; stroke-linecap: round; stroke-linejoin: round; }
.story-client.waiting > svg { stroke-dasharray: 3 2; }
.story-client.offline > span, .external-service.unknown > span { color: var(--dasp-warning); }
.external-service small { margin-top: 8px; font-size: 10px; color: var(--vp-c-text-2); }
.story-wire { position: relative; height: 2px; margin-right: 8px; background: var(--dasp-line); }
.tool-wire { margin-left: 8px; margin-right: 8px; }
.story-wire.disconnected { background: none; border-top: 1px dashed var(--dasp-warning); }
.story-wire svg { position: absolute; width: 16px; height: 16px; top: -8px; left: 2px; background: var(--vp-c-bg-soft); stroke: var(--dasp-warning); stroke-width: 1.5; }
.message-packet { display: block; width: 7px; height: 7px; border-radius: 2px; background: var(--vp-c-brand-1); position: absolute; top: -2.5px; animation: command-arrives 700ms cubic-bezier(.16,1,.3,1) both; }
.message-packet.returning { animation-name: update-returns; }
.message-packet.lost-packet { background: var(--dasp-warning); animation-name: reply-lost; }
.message-packet.lost-receipt { background: var(--dasp-warning); animation: reply-lost 650ms ease-out 700ms both; }
.story-server { border: 1px solid var(--vp-c-brand-1); border-radius: 8px; padding: 17px 16px 12px; background: var(--vp-c-bg); }
.server-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 4px 12px; }
.server-heading strong { font-size: 16px; font-weight: 650; color: var(--vp-c-brand-1); }
.server-heading > span { font-size: 11px; color: var(--vp-c-text-2); }
.story-server .server-actor { font-size: 11px; color: var(--vp-c-text-2); margin: 4px 0 18px; line-height: 1.5; }
.story-server .saved-records { min-height: 153px; list-style: none; padding: 0; margin: 0; }
.saved-records li { display: flex; gap: 10px; align-items: flex-start; padding: 8px 0; margin: 0; }
.record-sequence { flex: 0 0 20px; height: 20px; border: 1px solid var(--vp-c-divider); border-radius: 50%; font-family: var(--vp-font-family-mono); font-size: 10px; line-height: 18px; text-align: center; margin-top: 1px; color: var(--vp-c-text-2); }
.saved-records strong { display: block; font-size: 13px; font-weight: 550; line-height: 1.5; }
.saved-records div > span { display: block; font-size: 11px; line-height: 1.6; color: var(--vp-c-text-2); }
.saved-records .uncertain strong { color: var(--dasp-warning); }
.story-server .server-retention { border-top: 1px solid var(--vp-c-divider); padding-top: 9px; margin: 10px 0 0; color: var(--vp-c-text-2); font-size: 10px; line-height: 1.5; }
.story-figure figcaption { font-size: 12px; line-height: 1.6; color: var(--vp-c-text-2); }
.scene-explanation { padding: 25px 0 0; }
.scene-explanation h3 { margin: 0 0 10px; font-size: 24px; line-height: 1.3; letter-spacing: -.02em; font-weight: 600; text-wrap: balance; }
.scene-explanation > p { margin: 0 0 20px; font-size: 15px; }
.scene-evidence { display: grid; grid-template-columns: 1fr 1fr; gap: 28px; margin: 22px 0; }
.scene-evidence dt { font-size: 13px; font-weight: 650; margin: 0 0 6px; }
.scene-evidence dd { margin: 0; font-size: 14px; line-height: 1.7; color: var(--vp-c-text-2); }
.scene-explanation .story-lesson { font-size: 16px; font-weight: 550; color: var(--vp-c-brand-1); }
.message-details { border-top: 1px solid var(--vp-c-divider); border-bottom: 1px solid var(--vp-c-divider); padding: 14px 0; }
.message-details summary { cursor: pointer; font-size: 13px; font-weight: 550; min-height: 24px; }
.message-details summary:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 5px; }
.message-details p { font-size: 13px; line-height: 1.75; }
.message-details a { display: inline-flex; align-items: center; gap: 8px; }
.message-details pre { max-height: 420px; overflow: auto; padding: 18px; background: var(--vp-c-bg-alt); border-radius: 6px; font-size: 12px; line-height: 1.8; }
.message-details pre code { padding: 0; background: transparent; font-size: inherit; color: var(--vp-c-text-1); }
.scene-navigation { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 15px 0; }
.scene-navigation button { display: inline-flex; align-items: center; gap: 8px; min-height: 44px; padding: 0 8px; font-size: 13px; color: var(--vp-c-text-2); }
.scene-navigation button:hover:not(:disabled) { background: var(--vp-c-brand-soft); color: var(--vp-c-brand-1); }
.scene-navigation button:disabled { opacity: .4; cursor: default; }
.scene-navigation > span { font-size: 11px; color: var(--vp-c-text-2); white-space: nowrap; }
.scene-navigation .next-scene { font-weight: 600; color: var(--vp-c-brand-1); }
.previous-arrow { transform: rotate(180deg); }
.walkthrough-story .story-scope { margin: 4px 0 0; font-size: 12px; line-height: 1.7; color: var(--vp-c-text-2); }
.saved-record-enter-active, .saved-record-leave-active, .saved-record-move { transition: transform 240ms cubic-bezier(.16,1,.3,1), opacity 180ms ease-out; }
.saved-record-enter-from, .saved-record-leave-to { opacity: 0; transform: translateX(-8px); }
@keyframes command-arrives { from { transform: translateX(-6px); opacity: 0; } 25% { opacity: 1; } to { transform: translateX(42px); opacity: 0; } }
@keyframes update-returns { from { transform: translateX(42px); opacity: 0; } 25% { opacity: 1; } to { transform: translateX(-6px); opacity: 0; } }
@keyframes reply-lost { from { transform: translateX(28px); opacity: 0; } 20% { opacity: 1; } to { transform: translateX(12px); opacity: 0; } }
@media (prefers-reduced-motion: reduce) {
  .message-packet { animation: none; display: none; }
  .saved-record-enter-active, .saved-record-leave-active, .saved-record-move { transition: opacity 100ms ease-out; }
  .saved-record-enter-from, .saved-record-leave-to { transform: none; }
}
@media (max-width: 640px) {
  .scene-tabs { grid-template-columns: repeat(3, minmax(0, 1fr)); row-gap: 4px; }
  .scene-tabs button { flex-direction: row; gap: 8px; min-height: 44px; padding: 12px 8px; }
  .story-figure { padding: 18px; }
  .story-identity { flex-direction: column; }
  .story-network { grid-template-columns: 1fr; margin-top: 20px; }
  .story-clients { flex-direction: row; gap: 20px; }
  .story-client { flex: 1; }
  .story-client > svg { width: 21px; height: 21px; }
  .story-wire { height: 26px; width: 1px; margin: 10px 0 10px 25%; }
  .story-wire.disconnected { border-top: 0; border-left: 1px dashed var(--dasp-warning); }
  .story-wire svg { top: 4px; left: -8px; }
  .message-packet { top: 0; left: -3px; animation-name: command-arrives-down; }
  .message-packet.returning { animation-name: update-returns-up; }
  .message-packet.lost-packet { animation-name: tool-reply-lost; }
  .message-packet.lost-receipt { animation-name: tool-reply-lost; }
  .tool-wire { margin-left: 75%; }
  .external-service { display: grid; grid-template-columns: 25px 1fr; gap: 2px 10px; }
  .external-service svg { grid-row: span 2; }
  .external-service small { grid-column: 2; margin-top: 3px; }
  .story-server .saved-records { min-height: 151px; }
  .scene-evidence { grid-template-columns: 1fr; gap: 16px; }
  .scene-explanation h3 { font-size: 22px; }
  .scene-navigation { flex-wrap: wrap; }
  .scene-navigation > span { order: -1; width: 100%; text-align: center; }
  .scene-navigation button { padding: 0; }
  @keyframes command-arrives-down { from { transform: translateY(-2px); opacity: 0; } 25% { opacity: 1; } to { transform: translateY(22px); opacity: 0; } }
  @keyframes update-returns-up { from { transform: translateY(22px); opacity: 0; } 25% { opacity: 1; } to { transform: translateY(-2px); opacity: 0; } }
  @keyframes tool-reply-lost { from { transform: translateY(22px); opacity: 1; } to { transform: translateY(12px); opacity: 0; } }
}
</style>
