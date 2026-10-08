<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
defineProps({ kind: { type: String, required: true } });
const root = ref(null);
const visible = ref(false);
const hidden = ref(false);
const reduced = ref(true);
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
  actors: 'Clients connect through a DASP server.',
  admission: 'From client intent to a saved outcome.',
  recovery: 'Resume after the last applied update.',
  multiplayer: 'One history. A position for each client.'
};
const clients = [
  { x: 96, name: 'Web app', cursor: 5 },
  { x: 240, name: 'CLI', cursor: 3 },
  { x: 384, name: 'Service', cursor: 4 }
];
</script>

<template>
  <figure ref="root" class="protocol-explainer" :class="{ running: visible && !hidden && !reduced, 'static-motion': reduced }">
    <figcaption>{{ titles[kind] }}</figcaption>
    <svg v-if="kind === 'actors'" class="explainer-svg" viewBox="0 0 480 350" role="img" aria-label="A web app, command-line tool, and service connect to a DASP server. The server manages sessions for workflow, device, and agent actors. These are example application roles.">
      <rect class="server-boundary" x="24" y="124" width="432" height="206" rx="10"/>
      <path class="wire" d="M96 76V104H240V146M240 76V146M384 76V104H240"/>
      <path class="wire flow" d="M96 76V104H240V146M240 76V146M384 76V104H240"/>
      <g v-for="client in clients" :key="client.name" class="node">
        <rect :x="client.x - 56" y="32" width="112" height="44" rx="6"/>
        <text class="svg-label" :x="client.x" y="59">{{ client.name }}</text>
      </g>
      <rect class="contract-node" x="132" y="146" width="216" height="52" rx="6"/>
      <text class="contract-label" x="240" y="168">DASP server</text>
      <text class="contract-detail" x="240" y="186">Sessions · commands · history</text>
      <path class="wire" d="M240 198V230H96V266M240 230V266M240 230H384V266"/>
      <g v-for="(actor, i) in ['Workflow', 'Device', 'Agent']" :key="actor" class="node">
        <rect :x="40 + i * 144" y="266" width="112" height="44" rx="6"/>
        <text class="svg-label" :x="96 + i * 144" y="285">{{ actor }}</text>
        <text class="node-detail" :x="96 + i * 144" y="301">actor</text>
      </g>
    </svg>
    <div v-else-if="kind === 'admission'" class="admission-visual">
      <div class="identity-strip"><span>Stable command ID</span><code>cmd-042</code></div>
      <ol class="event-sequence" aria-label="Example of an accepted command">
        <li class="intent-event"><span class="event-point" aria-hidden="true"></span><div><span class="event-owner">Client</span><strong>Submit a command</strong><span>Keep its ID and data for retries.</span></div></li>
        <li class="receipt-event"><span class="event-point" aria-hidden="true"></span><div><span class="event-owner">Server</span><strong>Save admission</strong><span>Then return an accepted receipt.</span></div></li>
        <li class="outcome-event"><span class="event-point" aria-hidden="true"></span><div><span class="event-owner">Server</span><strong>Save the outcome</strong><span>Completed · failed · cancelled · uncertain</span></div></li>
      </ol>
      <p class="diagram-aside">Progress is temporary. The outcome is saved.</p>
    </div>
    <svg v-else-if="kind === 'recovery'" class="explainer-svg" viewBox="0 0 480 330" role="img" aria-label="Example: a client disconnects with its applied cursor at update 2. The DASP server retains updates 1 through 5. After reconnecting, the client reads updates 3 through 5 and applies them in order.">
      <text class="svg-label" x="101" y="34">Before disconnect</text><text class="svg-label" x="379" y="34">After reconnect</text>
      <g class="node"><rect x="34" y="52" width="134" height="46" rx="6"/><rect x="312" y="52" width="134" height="46" rx="6"/></g>
      <text class="svg-label" x="101" y="81">Cursor: 2</text><text class="svg-label" x="379" y="81">Read after 2</text>
      <path class="wire old-connection" d="M101 98V164"/><path class="wire" d="M379 98V164"/><path class="wire flow replay-flow" d="M379 164V98"/>
      <rect class="history-box" x="24" y="164" width="432" height="142" rx="8"/>
      <text class="svg-label" x="240" y="194">DASP server · saved session history</text>
      <rect class="replay-range" x="218" y="214" width="204" height="44" rx="22"/>
      <path class="wire" d="M80 236H400"/>
      <g v-for="n in 5" :key="n" :class="n > 2 ? 'replay-event' : 'past-event'">
        <circle :cx="n * 80" cy="236" r="12"/>
        <text class="sequence-number" :x="n * 80" y="240">{{ n }}</text>
      </g>
      <circle class="cursor-ring" cx="160" cy="236" r="18"/>
      <text class="svg-note" x="120" y="285">Applied through 2</text><text class="svg-note" x="320" y="285">Replay 3–5</text>
    </svg>
    <svg v-else-if="kind === 'multiplayer'" class="explainer-svg" viewBox="0 0 480 350" role="img" aria-label="Example: a DASP server keeps one actor session with updates 1 through 5. A web app has applied update 5, a command-line client update 3, and a service update 4. Each authorized client can recover from its own saved cursor.">
      <rect class="server-boundary" x="24" y="24" width="432" height="168" rx="10"/>
      <text class="server-label" x="240" y="57">DASP server</text>
      <text class="svg-label" x="240" y="85">One actor session · saved updates</text>
      <path class="wire" d="M80 132H400"/>
      <g v-for="n in 5" :key="n" class="replay-event">
        <circle :cx="n * 80" cy="132" r="12"/>
        <text class="sequence-number" :x="n * 80" y="136">{{ n }}</text>
      </g>
      <text class="svg-note" x="240" y="170">Same order for every client</text>
      <path class="wire" d="M96 192V250M240 192V250M384 192V250"/>
      <path class="wire flow" d="M96 192V250M240 192V250M384 192V250"/>
      <g v-for="client in clients" :key="client.name" class="node">
        <rect :x="client.x - 56" y="250" width="112" height="66" rx="6"/>
        <text class="svg-label" :x="client.x" y="275">{{ client.name }}</text>
        <text class="client-cursor" :x="client.x" y="300">Cursor: {{ client.cursor }}</text>
      </g>
    </svg>
  </figure>
</template>

<style scoped>
.protocol-explainer { margin: 0; background: var(--vp-c-bg-soft); border: 1px solid var(--vp-c-divider); border-radius: 12px; overflow: hidden; }
.protocol-explainer figcaption { padding: 20px 24px; font-size: 14px; line-height: 1.5; font-weight: 600; border-bottom: 1px solid var(--vp-c-divider); }
.explainer-svg { display: block; width: 100%; height: auto; }
.wire { fill: none; stroke: var(--dasp-line); stroke-width: 1.3; }
/* Each diagram moves for at most four seconds, then remains still. */
.flow { stroke: var(--vp-c-brand-1); stroke-width: 2; stroke-dasharray: 5 19; animation: signal-flow 2s linear 2; animation-play-state: paused; }
.node rect, .history-box { fill: var(--vp-c-bg); stroke: var(--vp-c-divider); }
.server-boundary { fill: var(--vp-c-brand-soft); stroke: var(--dasp-line); stroke-width: 1; }
.svg-label { fill: var(--vp-c-text-1); font-size: 14px; text-anchor: middle; font-weight: 500; }
.contract-node { fill: var(--dasp-button-bg); }
.contract-label { fill: var(--dasp-button-text); font-size: 16px; font-weight: 650; text-anchor: middle; }
.contract-detail { fill: var(--dasp-button-text); font-size: 11px; text-anchor: middle; }
.server-label { fill: var(--vp-c-brand-1); font-size: 16px; font-weight: 650; text-anchor: middle; }
.node-detail { fill: var(--vp-c-text-2); font-size: 11px; text-anchor: middle; }
.svg-note { fill: var(--vp-c-text-2); font-size: 12px; text-anchor: middle; }
.replay-range { fill: var(--vp-c-brand-soft); }
.past-event circle { fill: var(--vp-c-bg); stroke: var(--dasp-line); }
.past-event text { fill: var(--vp-c-text-2); }
.replay-event circle { fill: var(--dasp-button-bg); }
.replay-event text { fill: var(--dasp-button-text); }
.sequence-number { font-family: var(--vp-font-family-mono); font-size: 11px; text-anchor: middle; }
.client-cursor { fill: var(--vp-c-brand-1); font-family: var(--vp-font-family-mono); font-size: 12px; text-anchor: middle; }
.cursor-ring { fill: none; stroke: var(--vp-c-brand-1); stroke-width: 1.5; }
.old-connection { stroke-dasharray: 3 4; opacity: .4; animation: connection-fade 3s ease-out both; animation-play-state: paused; }
.admission-visual { padding: 24px; }
.identity-strip { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 14px; justify-content: space-between; font-size: 12px; color: var(--vp-c-text-2); }
.identity-strip code { font-size: 12px; color: var(--vp-c-brand-1); }
.event-sequence { list-style: none; padding: 0; margin: 26px 0; }
.event-sequence li { position: relative; display: flex; align-items: flex-start; gap: 18px; padding: 0 0 25px; margin: 0; }
.event-sequence li:not(:last-child)::before { content: ''; position: absolute; width: 1px; background: var(--dasp-line); top: 13px; bottom: 0; left: 6px; }
.event-sequence li:last-child { padding-bottom: 0; }
.event-point { width: 13px; height: 13px; margin-top: 4px; border-radius: 50%; border: 2px solid var(--vp-c-brand-1); flex-shrink: 0; background: var(--vp-c-bg); animation: event-emphasis 3s ease-out both; animation-play-state: paused; }
.receipt-event .event-point { animation-delay: .5s; }
.outcome-event .event-point { animation-delay: 1s; }
.event-sequence strong { display: block; font-size: 16px; font-weight: 600; line-height: 1.5; }
.event-sequence div > span { display: block; color: var(--vp-c-text-2); font-size: 13px; line-height: 1.7; }
.event-sequence div > .event-owner { margin-bottom: 3px; font-size: 11px; text-transform: uppercase; letter-spacing: .08em; color: var(--vp-c-brand-1); }
.admission-visual .diagram-aside { font-size: 12px; margin: 0; padding-top: 16px; border-top: 1px solid var(--vp-c-divider); line-height: 1.6; color: var(--vp-c-text-2); }
.running .flow, .running .old-connection, .running .event-point { animation-play-state: running; }
.static-motion .flow { stroke-dasharray: none; opacity: .6; }
@keyframes signal-flow { to { stroke-dashoffset: -48; } }
@keyframes connection-fade { from { opacity: 1; } to { opacity: .4; } }
@keyframes event-emphasis { 0%, 100% { background: var(--vp-c-bg); } 25%, 65% { background: var(--vp-c-brand-1); } }
@media (prefers-reduced-motion: reduce) { .flow, .old-connection, .event-point { animation: none; } }
@media (max-width: 480px) {
  .protocol-explainer figcaption { padding: 18px; }
  .admission-visual { padding: 22px 18px; }
  .svg-label { font-size: 18px; }
  .contract-label, .server-label { font-size: 20px; }
  .contract-detail { font-size: 13px; }
  .node-detail, .client-cursor { font-size: 15px; }
  .svg-note { font-size: 16px; }
  .sequence-number { font-size: 15px; }
}
</style>
