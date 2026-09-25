<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
const props = defineProps({ kind: { type: String, required: true } });
const root = ref(null);
const visible = ref(false);
const hidden = ref(false);
const reduced = ref(true);
const paused = ref(false);
let observer;
let preference;
const syncVisibility = () => { hidden.value = document.hidden; };
const syncPreference = () => { reduced.value = preference.matches; };
onMounted(() => {
  preference = window.matchMedia('(prefers-reduced-motion: reduce)');
  syncPreference();
  syncVisibility();
  preference.addEventListener('change', syncPreference);
  document.addEventListener('visibilitychange', syncVisibility);
  if ('IntersectionObserver' in window) {
    observer = new IntersectionObserver(([entry]) => { visible.value = entry.isIntersecting; }, { threshold: 0.15 });
    observer.observe(root.value);
  } else { visible.value = true; }
});
onBeforeUnmount(() => {
  observer?.disconnect();
  preference?.removeEventListener('change', syncPreference);
  document.removeEventListener('visibilitychange', syncVisibility);
});
const titles = {
  actors: 'Clients connect through an actor host.',
  admission: 'Acceptance and completion are separate facts.',
  recovery: 'A connection is temporary. Saved history remains.',
  multiplayer: 'Shared updates. Separate client cursors.'
};
</script>

<template>
  <figure ref="root" class="protocol-explainer" :class="{ running: visible && !hidden && !paused && !reduced, 'static-motion': reduced }">
    <figcaption>{{ titles[kind] }}</figcaption>
    <svg v-if="kind === 'actors'" class="explainer-svg" viewBox="0 0 480 330" role="img" aria-label="A web client, command-line client, and service connect through a DASP host authority to actors for workflows, devices, and agents. These are illustrative application roles.">
      <g class="wire"><path d="M96 80V122H240V151M240 80V151M384 80V122H240M240 191V224H96V254M240 191V254M240 224H384V254" /></g>
      <g class="wire flow"><path d="M96 80V122H240V151M240 80V151M384 80V122H240M240 191V224H96V254M240 191V254M240 224H384V254" /></g>
      <g class="node"><rect x="40" y="38" width="112" height="42" rx="6"/><rect x="184" y="38" width="112" height="42" rx="6"/><rect x="328" y="38" width="112" height="42" rx="6"/></g>
      <g class="svg-label"><text x="96" y="64">Web client</text><text x="240" y="64">CLI</text><text x="384" y="64">Service</text></g>
      <rect class="contract-node" x="155" y="151" width="170" height="40" rx="6"/><text class="contract-label" x="240" y="177">DASP host</text>
      <g class="node"><rect x="40" y="254" width="112" height="42" rx="6"/><rect x="184" y="254" width="112" height="42" rx="6"/><rect x="328" y="254" width="112" height="42" rx="6"/></g>
      <g class="svg-label"><text x="96" y="280">Workflow actor</text><text x="240" y="280">Device actor</text><text x="384" y="280">Agent actor</text></g>
    </svg>
    <div v-else-if="kind === 'admission'" class="admission-visual" role="img" aria-label="A command keeps its identity. A receipt reports admission. A later saved outcome reports completion, failure, or uncertainty. Progress cannot establish completion.">
      <div class="identity-strip"><span>Command identity</span><code>same ID throughout</code></div>
      <ol class="event-sequence">
        <li class="intent-event"><span class="event-point"></span><div><strong>Command</strong><span>Client intent</span></div></li>
        <li class="receipt-event"><span class="event-point"></span><div><strong>Receipt</strong><span>Admission only</span></div></li>
        <li class="outcome-event"><span class="event-point"></span><div><strong>Saved outcome</strong><span>Completed, failed, or uncertain</span></div></li>
      </ol>
      <p class="diagram-aside">Temporary progress does not settle a command.</p>
    </div>
    <svg v-else-if="kind === 'recovery'" class="explainer-svg" viewBox="0 0 480 330" role="img" aria-label="An earlier connection ends. Saved updates stay in the session. A later connection reads after the last applied cursor, preserving history.">
      <text class="svg-label" x="101" y="35">Earlier connection</text><text class="svg-label" x="379" y="35">Later connection</text>
      <g class="node"><rect x="45" y="53" width="112" height="43" rx="6"/><rect x="323" y="53" width="112" height="43" rx="6"/></g>
      <text class="svg-label" x="101" y="80">Client</text><text class="svg-label" x="379" y="80">Client</text>
      <path class="wire old-connection" d="M101 96V174"/><path class="wire" d="M379 96V174"/><path class="wire flow replay-flow" d="M379 174V96"/>
      <text class="svg-note" x="101" y="129">Connection ends</text><text class="svg-note" x="379" y="129">Read after cursor</text>
      <rect class="history-box" x="32" y="174" width="416" height="116" rx="8"/>
      <text class="svg-label" x="240" y="202">Saved session history</text>
      <path class="wire" d="M89 242H392"/>
      <g class="saved-event"><circle cx="89" cy="242" r="7"/><circle cx="164" cy="242" r="7"/><circle cx="240" cy="242" r="7"/><circle cx="316" cy="242" r="7"/><circle cx="392" cy="242" r="7"/></g>
      <circle class="cursor-ring" cx="164" cy="242" r="14"/>
      <text class="svg-note" x="164" y="275">Last applied cursor</text>
    </svg>
    <svg v-else-if="kind === 'multiplayer'" class="explainer-svg" viewBox="0 0 480 330" role="img" aria-label="One actor session sends saved updates to three clients. Each client keeps a separate update cursor. The host checks authorization. Each client reads the same ordered saved history.">
      <rect class="contract-node" x="140" y="30" width="200" height="44" rx="6"/>
      <text class="contract-label" x="240" y="58">Actor session</text>
      <path class="wire" d="M240 74V116"/>
      <rect class="history-box" x="40" y="116" width="400" height="64" rx="6"/>
      <text class="svg-label" x="240" y="142">One ordered update history</text>
      <path class="wire" d="M100 161H380"/>
      <g class="saved-event"><circle cx="100" cy="161" r="4"/><circle cx="170" cy="161" r="4"/><circle cx="240" cy="161" r="4"/><circle cx="310" cy="161" r="4"/><circle cx="380" cy="161" r="4"/></g>
      <path class="wire" d="M96 180V246M240 180V246M384 180V246"/>
      <path class="wire flow" d="M96 180V246M240 180V246M384 180V246"/>
      <g class="node"><rect x="40" y="246" width="112" height="44" rx="6"/><rect x="184" y="246" width="112" height="44" rx="6"/><rect x="328" y="246" width="112" height="44" rx="6"/></g>
      <g class="svg-label"><text x="96" y="273">Web client</text><text x="240" y="273">CLI</text><text x="384" y="273">Service</text></g>
      <g class="svg-note"><text x="96" y="312">Own cursor</text><text x="240" y="312">Own cursor</text><text x="384" y="312">Own cursor</text></g>
    </svg>
    <div class="explainer-controls"><span>{{ kind === 'actors' ? 'Host authority · admission, history, recovery' : 'Protocol explanation · no live execution' }}</span><button v-if="!reduced" type="button" :aria-label="`${paused ? 'Play' : 'Pause'} animation: ${titles[kind]}`" :aria-pressed="paused" @click="paused = !paused">{{ paused ? 'Play' : 'Pause' }}</button><span v-else class="motion-note">Static view</span></div>
  </figure>
</template>

<style scoped>
.protocol-explainer { margin: 0; background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); border-radius: 12px; overflow: hidden; }
.protocol-explainer figcaption { padding: 20px 24px; font-size: 14px; line-height: 1.5; font-weight: 600; border-bottom: 1px solid var(--vp-c-divider); }
.explainer-svg { display: block; width: 100%; height: auto; }
.wire { fill: none; stroke: var(--dasp-line); stroke-width: 1.3; }
.flow { stroke: var(--vp-c-brand-1); stroke-width: 2; stroke-dasharray: 5 19; animation: signal-flow 3s linear infinite; animation-play-state: paused; }
.node rect { fill: var(--vp-c-bg); stroke: var(--vp-c-divider); }
.svg-label { fill: var(--vp-c-text-1); font-size: 13px; text-anchor: middle; font-weight: 500; }
.contract-node { fill: var(--dasp-button-bg); }
.contract-label { fill: var(--dasp-button-text); font-size: 15px; font-weight: 650; text-anchor: middle; }
.svg-note { fill: var(--vp-c-text-2); font-size: 11px; text-anchor: middle; paint-order: stroke; stroke: var(--vp-c-bg-soft); stroke-width: 7px; stroke-linejoin: round; }
.history-box { fill: var(--vp-c-bg); stroke: var(--vp-c-divider); }
.saved-event { fill: var(--vp-c-brand-1); }
.cursor-ring { fill: var(--vp-c-bg); stroke: var(--vp-c-brand-1); stroke-width: 2; }
.old-connection { stroke-dasharray: 3 4; animation: connection-fade 8s ease-in-out infinite; animation-play-state: paused; }
.replay-flow { animation-duration: 2s; }
.explainer-controls { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 10px 16px 10px 24px; border-top: 1px solid var(--vp-c-divider); font-size: 11px; line-height: 1.5; color: var(--vp-c-text-2); }
.explainer-controls button { min-height: 44px; min-width: 56px; font-size: 12px; font-weight: 600; color: var(--vp-c-brand-1); border-radius: 4px; }
.explainer-controls button:hover { background: var(--vp-c-brand-soft); }
.motion-note { white-space: nowrap; }
.admission-visual { padding: 24px; }
.identity-strip { display: flex; flex-wrap: wrap; gap: 6px 14px; justify-content: space-between; font-size: 12px; color: var(--vp-c-text-2); }
.identity-strip code { font-size: 11px; color: var(--vp-c-brand-1); }
.event-sequence { list-style: none; padding: 0; margin: 24px 0; }
.event-sequence li { position: relative; display: flex; align-items: flex-start; gap: 18px; padding: 0 0 26px; margin: 0; }
.event-sequence li:not(:last-child)::before { content: ''; position: absolute; width: 1px; background: var(--dasp-line); top: 13px; bottom: 0; left: 6px; }
.event-sequence li:last-child { padding-bottom: 0; }
.event-point { width: 13px; height: 13px; margin-top: 5px; border-radius: 50%; border: 2px solid var(--vp-c-brand-1); flex-shrink: 0; background: var(--vp-c-bg); animation: event-emphasis 9s ease-in-out infinite; animation-play-state: paused; }
.receipt-event .event-point { animation-delay: 1.5s; }
.outcome-event .event-point { animation-delay: 3s; }
.event-sequence strong { display: block; font-size: 15px; font-weight: 600; line-height: 1.5; }
.event-sequence div > span { display: block; color: var(--vp-c-text-2); font-size: 13px; line-height: 1.7; }
.admission-visual .diagram-aside { font-size: 12px; margin: 0; line-height: 1.6; color: var(--vp-c-text-2); }
.running .flow, .running .old-connection, .running .event-point { animation-play-state: running; }
.static-motion .flow { stroke-dasharray: none; opacity: .6; }
@keyframes signal-flow { to { stroke-dashoffset: -48; } }
@keyframes connection-fade { 0%, 15%, 90%, 100% { opacity: 1; } 35%, 70% { opacity: .18; } }
@keyframes event-emphasis { 0%, 12%, 65%, 100% { background: var(--vp-c-bg); } 22%, 50% { background: var(--vp-c-brand-1); } }
@media (prefers-reduced-motion: reduce) { .flow, .old-connection, .event-point { animation: none; } }
@media (max-width: 480px) { .protocol-explainer figcaption { padding: 18px; } .explainer-controls { padding-left: 18px; } .admission-visual { padding: 22px 18px; } }
</style>
