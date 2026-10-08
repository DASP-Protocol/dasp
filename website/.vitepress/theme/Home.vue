<script setup>
import { withBase } from 'vitepress';
import ArrowIcon from './ArrowIcon.vue';
import ProtocolExplainer from './ProtocolExplainer.vue';
import CommandOverview from './CommandOverview.vue';
const link = (p) => withBase(p);
</script>

<template>
  <div class="dasp-home">
    <section class="intro" aria-labelledby="hero-title">
      <div class="hero-grid">
        <div class="hero-copy">
          <h1 id="hero-title">Durable Actor<br>Session Protocol</h1>
          <p class="hero-tagline">A server protocol for durable actors.</p>
          <p class="hero-description">The connection can end. The work can continue. Discover what an actor offers, send commands, read saved outcomes, and return to the same actor session.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/guide/walkthrough.html')">Follow a command <ArrowIcon /></a>
            <a class="text-link" :href="link('/guide/comparisons.html')">Compare protocols <ArrowIcon /></a>
          </div>
        </div>
        <ProtocolExplainer kind="actors" />
      </div>
    </section>

    <section class="explanation-row discovery-row" aria-labelledby="discovery-title">
      <div class="explanation-copy">
        <p class="section-label">Capability discovery</p>
        <h2 id="discovery-title">Learn before<br>you open.</h2>
        <p>An optional setup contract reveals the actor’s exact profile and a bounded view of its commands. A large actor returns stable summary pages. The client reads details and schema resources only for the commands it needs.</p>
        <p>Discovery describes commands. It does not authorize them.</p>

        <a class="text-link" :href="link('/guide/capability-discovery.html')">Follow discovery <ArrowIcon /></a>
      </div>
      <ol class="setup-flow" aria-label="Capability discovery and session setup flow">
        <li><span>1</span><div><strong>Select</strong><small>Authenticate one exact discovery mapping.</small></div></li>
        <li><span>2</span><div><strong>List</strong><small>Read bounded summaries from one stable snapshot.</small></div></li>
        <li><span>3</span><div><strong>Inspect</strong><small>Request selected details and exact schema resources.</small></div></li>
        <li><span>4</span><div><strong>Confirm</strong><small>Confirm the profile, binding, extensions, and limits.</small></div></li>
        <li><span>5</span><div><strong>Open</strong><small>Assert the profile and start the durable session.</small></div></li>
      </ol>
    </section>

    <section class="explanation-row command-overview-section" aria-labelledby="how-title">
      <div class="explanation-copy">
        <h2 id="how-title">Use the durable session</h2>
        <p>After setup, five core operations connect your client to the actor’s saved record.</p>
        <a class="text-link" :href="link('/guide/walkthrough.html')">Inspect the messages <ArrowIcon /></a>
      </div>
      <div class="operations-panel"><CommandOverview /></div>
    </section>

    <section class="explanation-row" aria-labelledby="admission-title">
      <div class="explanation-copy">
        <p class="section-label">Command admission</p>
        <h2 id="admission-title">Know what<br>the server saved.</h2>
        <p>The server saves acceptance before replying. It records the final outcome separately. If effects cannot be established, the outcome is uncertain.</p>

        <a class="text-link" :href="link('/specification/messages.html')">Understand the messages <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="admission" />
    </section>

    <section class="explanation-row recovery-row" aria-labelledby="recovery-title">
      <ProtocolExplainer kind="recovery" />
      <div class="explanation-copy">
        <p class="section-label">Connection recovery</p>
        <h2 id="recovery-title">Reconnect to<br>the same record.</h2>
        <p>The server retains ordered updates when a connection ends. A returning client reads after the last update it applied.</p>

        <a class="text-link" :href="link('/specification/recovery.html')">Read the recovery rules <ArrowIcon /></a>
      </div>
    </section>

    <section class="explanation-row" aria-labelledby="multiplayer-title">
      <div class="explanation-copy">
        <p class="section-label">Shared sessions</p>
        <h2 id="multiplayer-title">Many clients.<br>One shared session.</h2>
        <p>A web app, command-line tool, and service can use the same actor session. The server checks access and gives each client the same ordered history.</p>

        <a class="text-link" :href="link('/specification/profiles-and-bindings.html#dasp-profile-003')">Understand shared sessions <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="multiplayer" />
    </section>

    <section class="contract-section" aria-labelledby="contract-title">
      <div><h2 id="contract-title">Common rules.<br>Native clients.</h2><p>Choose Elixir or TypeScript. Both use the same messages and recovery rules. Elixir includes a WebSocket client. TypeScript accepts your transport. Your application supplies authenticated setup, profile rules, and durable storage.</p><a class="text-link" :href="link('/specification/index.html')">Read the specification <ArrowIcon /></a></div>
      <div class="client-table">
        <a :href="link('/build/elixir.html')"><span><strong>Elixir</strong><small>Native API · shared wire contract</small></span><span class="client-status planned">Experimental</span><ArrowIcon /></a>
        <a :href="link('/build/typescript.html')"><span><strong>TypeScript</strong><small>Independent client · shared wire contract</small></span><span class="client-status planned">Experimental</span><ArrowIcon /></a>
        <div class="client-footnote">Experimental clients. No production binding or host is released.</div>
      </div>
    </section>

    <footer class="home-footer"><span>DASP / Durable Actor Session Protocol</span><a :href="link('/about/')">About DASP <ArrowIcon /></a><a :href="link('/brand.html')">Brand &amp; assets <ArrowIcon /></a><a href="https://github.com/DASP-Protocol/dasp">Developed in the open <ArrowIcon /></a></footer>
  </div>
</template>

<style scoped>
.discovery-row { border-top: 1px solid var(--vp-c-divider); }
.command-overview-section { grid-template-columns: minmax(0, .8fr) minmax(0, 1.2fr); gap: 48px; }
.operations-panel { min-width: 0; overflow: hidden; border: 1px solid var(--vp-c-divider); border-radius: 12px; background: var(--vp-c-bg-soft); }
.operations-panel :deep(table) { display: table; margin: 0; width: 100%; }
.operations-panel :deep(caption) { padding: 18px 20px; }
.operations-panel :deep(th), .operations-panel :deep(td) { border: 0; border-top: 1px solid var(--vp-c-divider); padding: 14px 16px; }
.operations-panel :deep(tr) { background: transparent; }
.setup-flow { list-style: none; margin: 0; padding: 6px 0; border: 1px solid var(--vp-c-divider); border-radius: 12px; background: var(--vp-c-bg-soft); }
.setup-flow li { display: flex; gap: 16px; align-items: flex-start; margin: 0; padding: 15px 18px; }
.setup-flow li + li { border-top: 1px solid var(--vp-c-divider); }
.setup-flow li > span { display: grid; flex: 0 0 28px; width: 28px; height: 28px; place-items: center; border-radius: 50%; background: var(--dasp-positive-bg); color: var(--dasp-positive-text); font-family: var(--vp-font-family-mono); font-size: 11px; }
.setup-flow strong, .setup-flow small { display: block; }
.setup-flow strong { margin-bottom: 3px; font-size: 14px; font-weight: 650; color: var(--vp-c-text-1); }
.setup-flow small { font-size: 12px; line-height: 1.55; color: var(--vp-c-text-2); }
@media (max-width: 959px) {
  .command-overview-section { grid-template-columns: minmax(0, 1fr); gap: 24px; }
}
</style>
