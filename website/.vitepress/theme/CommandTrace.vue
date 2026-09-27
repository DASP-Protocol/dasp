<script setup>
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue';
import CloudEventsHelp from './CloudEventsHelp.vue';
import trace from '../../../conformance/fixtures/recovery-trace.json';
const notes = {
  open: 'Client → host. Select the session, actor, and profile.',
  opened: 'Host → client. Session identity is saved. No updates exist yet.',
  command: 'Client → host. Add 3. Keep the command ID and input for retries.',
  admission: 'Saved update 1. The host records acceptance before replying.',
  'lost-receipt': 'Host → client. This reply is lost. The command remains accepted.',
  state: 'Saved update 2. The counter value is now 3.',
  settlement: 'Saved update 3. The completed outcome is final.',
  retry: 'Client → host. Same command ID and input; new request ID.',
  duplicate: 'Host → client. Original admission at sequence 1. No second admission.',
  'outcome-read': 'Client → host. Ask for the command result.',
  outcome: 'Host → client. Return the saved outcome from sequence 3.',
  'read-one': 'First client → host. Read after its last applied position.',
  'page-one': 'Host → first client. Replay saved events with their original identities.',
  'read-two': 'Second client → host. Read the same session from position 0.',
  'page-two': 'Host → second client. Return the same saved history.',
  'changed-command': 'Client → host. Reuse the command ID with changed input.',
  conflict: 'Host → client. Reject the conflict. The saved command is unchanged.'
};

const index = ref(0);
const playing = ref(false);
const reduced = ref(false);
const step = computed(() => trace.steps[index.value]);
const event = computed(() => step.value.event);
const phases = [{ label: 'Open', at: 0 }, { label: 'Submit', at: 2 }, { label: 'Retry', at: 7 }, { label: 'Recover', at: 11 }, { label: 'Conflict', at: 15 }];
const phase = computed(() => phases.filter(p => p.at <= index.value).at(-1));
const phaseSteps = computed(() => trace.steps.map((entry, i) => ({ ...entry, i })).filter(entry => entry.i >= phase.value.at && entry.i < (phases.find(p => p.at > phase.value.at)?.at ?? trace.steps.length)));
const diagramHeight = computed(() => 100 + phaseSteps.value.length * 72);
const isSaved = entry => entry.event.type === 'dasp.v1.update';
const fromClient = entry => entry.event.source.includes('client');
const shortName = entry => entry.event.data.kind || entry.event.type.replace('dasp.v1.', '');
const history = computed(() => [
  { at: 3, label: '1 · Accepted' }, { at: 5, label: '2 · Value = 3' }, { at: 6, label: '3 · Completed' }
].filter(item => item.at <= index.value));
let timer;
let preference;
function pause() { playing.value = false; }
function select(value) { pause(); index.value = Number(value); }
function syncPreference() { reduced.value = preference.matches; if (reduced.value) pause(); }
function visibility() { if (document.hidden) pause(); }
watch(playing, value => {
  clearInterval(timer);
  if (value) timer = setInterval(() => {
    if (index.value < trace.steps.length - 1) index.value++;
    else pause();
  }, 2200);
});
function play() {
  if (playing.value) { pause(); return; }
  if (index.value === trace.steps.length - 1) index.value = 0;
  playing.value = true;
}
onMounted(() => {
  preference = window.matchMedia('(prefers-reduced-motion: reduce)');
  syncPreference();
  preference.addEventListener('change', syncPreference);
  document.addEventListener('visibilitychange', visibility);
});
onBeforeUnmount(() => {
  clearInterval(timer);
  preference?.removeEventListener('change', syncPreference);
  document.removeEventListener('visibilitychange', visibility);
});
</script>
<template>
  <section class="trace-player" aria-label="Interactive command exchange">
    <nav class="phases" aria-label="Trace stages">
      <button v-for="item in phases" :key="item.at" :aria-current="phase.at === item.at ? 'step' : undefined" @click="select(item.at)">{{ item.label }}</button>
    </nav>
    <div class="diagram-scroll">
    <svg :viewBox="`0 0 640 ${diagramHeight}`" role="group" :aria-label="`${phase.label}: select a message in the sequence diagram`" class="exchange">
      <rect class="participant" x="30" y="16" width="160" height="46" rx="6" />
      <rect class="participant" x="450" y="16" width="160" height="46" rx="6" />
      <text x="110" y="44">Client</text>
      <text x="530" y="44">Host / counter</text>
      <path class="lifeline" :d="`M110 62V${diagramHeight - 20} M530 62V${diagramHeight - 20}`" />
      <g v-for="(entry, row) in phaseSteps" :key="entry.id" :transform="`translate(0 ${86 + row * 72})`" class="sequence-row" :class="{ active: entry.i === index, past: entry.i < index }" role="button" tabindex="0" :aria-label="`Step ${entry.i + 1}: ${notes[entry.id]}`" :aria-current="entry.i === index ? 'step' : undefined" @click="select(entry.i)" @keydown.enter.prevent="select(entry.i)" @keydown.space.prevent="select(entry.i)">
        <rect class="row-background" x="16" y="-12" width="608" height="66" rx="6" />
        <text x="44" y="25" class="row-number">{{ entry.i + 1 }}</text>
        <text :x="isSaved(entry) ? 330 : 320" y="7" class="message-label">{{ shortName(entry) }}</text>
        <path v-if="isSaved(entry)" class="signal" d="M530 12H578V40H530l8 -5m-8 5l8 5" />
        <path v-else-if="entry.delivery === 'dropped'" class="signal lost" d="M530 26H325m-6 -6l12 12m0 -12l-12 12" />
        <path v-else class="signal" :d="fromClient(entry) ? 'M110 26H530l-8 -5m8 5l-8 5' : 'M530 26H110l8 -5m-8 5l8 5'" />
        <circle v-if="entry.i === index && !isSaved(entry) && !reduced && entry.delivery !== 'dropped'" :key="`packet-${index}`" r="4" cy="26" :cx="fromClient(entry) ? 110 : 530" class="packet" :class="fromClient(entry) ? 'to-host' : 'to-client'" />
        <text x="320" y="46" class="status-label">{{ isSaved(entry) ? `Saved update ${entry.event.data.sequence}` : entry.delivery === 'dropped' ? 'Receipt lost · work remains accepted' : entry.id === 'read-two' || entry.id === 'page-two' ? 'Second client' : entry.event.data.disposition || '' }}</text>
      </g>
    </svg>
    </div>
    <div class="saved-history" aria-label="Saved history at this step">
      <span>Saved history</span><span v-if="!history.length">No updates</span>
      <strong v-for="item in history" :key="item.at">{{ item.label }}</strong>
    </div>
    <div class="controls">
      <button @click="select(0)" aria-label="Restart trace">Restart</button>
      <button @click="select(index - 1)" :disabled="index === 0">Back</button>
      <button @click="play" :aria-pressed="playing">{{ playing ? 'Pause' : 'Play' }}</button>
      <button @click="select(index + 1)" :disabled="index === trace.steps.length - 1">Next</button>
      <label for="trace-position">Step {{ index + 1 }} / {{ trace.steps.length }}</label>
      <input id="trace-position" type="range" min="0" :max="trace.steps.length - 1" :value="index" @input="select($event.target.value)" />
    </div>
    <p class="step-note" aria-live="polite" aria-atomic="true">{{ notes[step.id] }}</p>
    <details open class="message-json">
      <summary>Message JSON · <code>{{ event.type }}</code></summary>
      <div class="json-help"><CloudEventsHelp /></div>
      <pre tabindex="0" :aria-label="`Full message: ${step.id}`"><code>{{ JSON.stringify(event, null, 2) }}</code></pre>
    </details>
  </section>
</template>
<style scoped>
.trace-player { border: 1px solid var(--vp-c-divider); border-radius: 12px; overflow: hidden; margin: 24px 0; }
.phases, .controls, .saved-history { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; padding: 16px 20px; }
.phases { border-bottom: 1px solid var(--vp-c-divider); }
button { border: 1px solid var(--vp-c-divider); border-radius: 6px; padding: 6px 12px; font: inherit; font-size: 14px; cursor: pointer; }
button[aria-current], button[aria-pressed="true"] { background: var(--dasp-button-bg); color: var(--dasp-button-text); }
button:disabled { opacity: .4; cursor: default; }
button:focus-visible, summary:focus-visible, input:focus-visible, pre:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 3px; }
.diagram-scroll { overflow-x: auto; }
.exchange { min-width: 460px; display: block; width: 100%; background: var(--vp-c-bg-soft); }
.participant { fill: var(--vp-c-bg); stroke: var(--vp-c-divider); }
text { text-anchor: middle; fill: var(--vp-c-text-1); font-size: 15px; }
.message-label { font-family: var(--vp-font-family-mono); font-size: 13px; }
.status-label { fill: var(--vp-c-text-2); font-size: 13px; }
.sequence-row { cursor: pointer; }
.row-background { fill: transparent; }
.sequence-row.active .row-background { fill: var(--vp-c-brand-soft); }
.sequence-row:focus-visible { outline: none; }
.sequence-row:focus-visible .row-background { stroke: var(--vp-c-brand-1); stroke-width: 2; }
.sequence-row:not(.active) .signal { opacity: .4; }
.row-number { fill: var(--vp-c-text-2); font-size: 12px; }
.lifeline { stroke: var(--vp-c-divider); stroke-dasharray: 4 4; }
.signal { stroke: var(--vp-c-brand-1); stroke-width: 2; fill: none; }
.lost { stroke-dasharray: 6 5; }
.packet { fill: var(--vp-c-brand-1); }
.to-host { animation: to-host 1.1s ease-in-out forwards; }
.to-client { animation: to-client 1.1s ease-in-out forwards; }
@keyframes to-host { to { transform: translateX(420px); opacity: 0; } }
@keyframes to-client { to { transform: translateX(-420px); opacity: 0; } }
.saved-history { font-size: 12px; border-bottom: 1px solid var(--vp-c-divider); }
.saved-history > span { color: var(--vp-c-text-2); }
.saved-history strong { background: var(--vp-c-brand-soft); padding: 3px 8px; border-radius: 4px; font-weight: 500; }
.controls label { font-size: 12px; margin-left: auto; }
input { width: 100%; accent-color: var(--vp-c-brand-1); }
.step-note { margin: 0; padding: 0 20px 20px; min-height: 64px; }
.json-help { padding: 0 20px; }
.message-json { border-top: 1px solid var(--vp-c-divider); }
summary { padding: 16px 20px; cursor: pointer; font-size: 13px; overflow-wrap: anywhere; }
pre { overflow-x: auto; margin: 0; padding: 20px; background: var(--vp-c-bg-soft); font-size: 12px; line-height: 1.7; max-height: 480px; }
@media (prefers-reduced-motion: reduce) { .packet { animation: none; display: none; } }
@media (max-width: 480px) { .phases, .controls { padding: 12px; gap: 6px; } button { padding: 6px 9px; } .controls label { margin-left: 0; } }
</style>
