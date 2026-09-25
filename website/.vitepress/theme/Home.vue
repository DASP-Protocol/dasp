<script setup>
import { withBase } from 'vitepress';
import ArrowIcon from './ArrowIcon.vue';
import ProtocolExplainer from './ProtocolExplainer.vue';
const link = (p) => withBase(p);
</script>

<template>
  <div class="dasp-home">
    <section class="intro" aria-labelledby="hero-title">
      <div class="hero-grid">
        <div class="hero-copy">
          <h1 id="hero-title">Durable Actor<br>Session Protocol</h1>
          <p class="hero-tagline">A shared protocol for durable actor sessions.</p>
          <p class="hero-description">Send commands to actors, follow saved outcomes, and resume after a connection fails. Built for agent builders using CloudEvents across languages.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/specification/')">Read the specification <ArrowIcon /></a>
            <a class="text-link" :href="link('/build/walkthrough.html')">Try the example <ArrowIcon /></a>
          </div>
          <div class="hero-context"><span class="draft-tag"><span class="status-dot"></span> Review draft</span><p class="hero-note">Draft-01 · Core may change. Elixir and TypeScript planned.</p></div>
        </div>
        <ProtocolExplainer kind="actors" />
      </div>
    </section>

    <section class="actor-introduction" aria-labelledby="actor-title">
      <h2 id="actor-title">Work survives<br>the client connection.</h2>
      <p>An actor performs application work. Its host keeps the session identity and saved history, so clients can return to the same facts. A profile defines the inputs and results. The core does not require a chat interface.</p>
    </section>

    <section class="explanation-row" aria-labelledby="admission-title">
      <div class="explanation-copy">
        <h2 id="admission-title">Accepted does not<br>mean completed.</h2>
        <p>A command carries a stable identity. Its receipt reports admission. A saved outcome tells the client what happened—even when the answer is uncertain.</p>
        <p>Temporary progress helps a client show activity. It cannot prove completion.</p>
        <a class="text-link" :href="link('/specification/messages.html')">Understand the messages <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="admission" />
    </section>

    <section class="explanation-row recovery-row" aria-labelledby="recovery-title">
      <ProtocolExplainer kind="recovery" />
      <div class="explanation-copy">
        <h2 id="recovery-title">The connection ends.<br>The session continues.</h2>
        <p>A disconnect does not cancel accepted work. Saved updates remain ordered within the session. A returning client reads after its last applied cursor.</p>
        <p>Retry unresolved intent with the same command ID and data. Keep recovery explicit.</p>
        <a class="text-link" :href="link('/specification/recovery.html')">Read the recovery rules <ArrowIcon /></a>
      </div>
    </section>

    <section class="explanation-row" aria-labelledby="multiplayer-title">
      <div class="explanation-copy">
        <h2 id="multiplayer-title">Many clients.<br>One shared session.</h2>
        <p>Follow the same actor from more than one client. The host controls command admission and saved state. Each client reads the saved updates with its own cursor.</p>
        <p>The host checks access. The application profile defines how concurrent commands interact. Each client recovers from its own saved state.</p>
        <a class="text-link" :href="link('/specification/profiles-and-bindings.html#dasp-profile-003')">Understand shared sessions <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="multiplayer" />
    </section>

    <section class="contract-section" aria-labelledby="contract-title">
      <div><h2 id="contract-title">Common rules.<br>Native clients.</h2><p>The specification defines the meaning. Each language chooses its API. Shared schemas and test cases define the target for both implementations.</p><a class="text-link" :href="link('/specification/index.html')">Read the specification <ArrowIcon /></a></div>
      <div class="client-table">
        <a :href="link('/build/clients.html#elixir')"><span><strong>Elixir</strong><small>Native API · shared wire contract</small></span><span class="client-status planned">Planned</span><ArrowIcon /></a>
        <a :href="link('/build/clients.html#typescript')"><span><strong>TypeScript</strong><small>Independent client · shared wire contract</small></span><span class="client-status planned">Planned</span><ArrowIcon /></a>
        <div class="client-footnote">No released DASP packages yet. Client status is explicit.</div>
      </div>
    </section>

    <section class="source-section" aria-labelledby="source-title">

      <div class="source-grid"><h2 id="source-title">Standard envelope.<br>Actor-specific data.</h2><div><p>CloudEvents supplies event identity and context. DASP supplies session, command, outcome, and replay rules. Profiles define the inputs and results for each kind of actor.</p><p class="source-note">Draft-01 has generic message schemas and examples. A production transport binding and application profile remain to be selected.</p><a class="text-link" :href="link('/project/feedback.html')">See the decisions ahead <ArrowIcon /></a></div></div>
    </section>

    <section class="start-section" aria-label="Start reading">
      <div><h2>Inspect the contract.<br>Check the evidence.</h2></div>
      <a class="primary-link" :href="link('/conformance/')">Explore conformance <ArrowIcon /></a>
    </section>
    <footer class="home-footer"><span>DASP / Durable Actor Session Protocol</span><a :href="link('/project/about.html')">About DASP <ArrowIcon /></a><a :href="link('/brand.html')">Brand &amp; assets <ArrowIcon /></a><a href="https://github.com/DASP-Protocol/dasp">Developed in the open <ArrowIcon /></a></footer>
  </div>
</template>
