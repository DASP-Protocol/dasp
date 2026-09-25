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
          <p class="hero-tagline">A server protocol for durable actors.</p>
          <p class="hero-description">Connect apps, tools, and agents to durable actor servers. Use CloudEvents to send commands, read saved outcomes, and recover across connections.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/specification/')">Read the specification <ArrowIcon /></a>
            <a class="text-link" :href="link('/build/walkthrough.html')">Follow a command <ArrowIcon /></a>
          </div>
        </div>
        <ProtocolExplainer kind="actors" />
      </div>
    </section>

    <section class="actor-introduction" aria-labelledby="actor-title">
      <h2 id="actor-title">Your server owns<br>the session.</h2>
      <div><p>The server is the authority for command admission, saved outcomes, and session history. Clients can disconnect and return to the same record.</p><p>Your application defines the actor's commands, state, and results. Chat is optional. The server can use any language or actor runtime.</p></div>
    </section>

    <section class="explanation-row" aria-labelledby="admission-title">
      <div class="explanation-copy">
        <p class="section-label">Command admission</p>
        <h2 id="admission-title">Know what<br>the server saved.</h2>
        <p>The server saves admission before it accepts a command. It records the final outcome separately, including an uncertain result when effects cannot be established.</p>
        <p>A retry keeps the command ID and data. It returns the saved admission without starting the work again.</p>
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
        <p>If the client stopped at update 2, it resumes with update 3. Accepted work continues independently of the connection.</p>
        <a class="text-link" :href="link('/specification/recovery.html')">Read the recovery rules <ArrowIcon /></a>
      </div>
    </section>

    <section class="explanation-row" aria-labelledby="multiplayer-title">
      <div class="explanation-copy">
        <p class="section-label">Shared sessions</p>
        <h2 id="multiplayer-title">Many clients.<br>One shared session.</h2>
        <p>A web app, command-line tool, and service can use the same actor session. The server checks access and gives each client the same ordered history.</p>
        <p>Clients can be at different positions. Each saves its own cursor and catches up at its own pace. The application profile defines how concurrent commands interact.</p>
        <a class="text-link" :href="link('/specification/profiles-and-bindings.html#dasp-profile-003')">Understand shared sessions <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="multiplayer" />
    </section>

    <section class="contract-section" aria-labelledby="contract-title">
      <div><h2 id="contract-title">Common rules.<br>Native clients.</h2><p>The specification defines the meaning. Each language chooses its API. Shared schemas and test cases define the target for both implementations.</p><a class="text-link" :href="link('/specification/index.html')">Read the specification <ArrowIcon /></a></div>
      <div class="client-table">
        <a :href="link('/build/clients.html#elixir')"><span><strong>Elixir</strong><small>Native API · shared wire contract</small></span><span class="client-status planned">Experimental</span><ArrowIcon /></a>
        <a :href="link('/build/clients.html#typescript')"><span><strong>TypeScript</strong><small>Independent client · shared wire contract</small></span><span class="client-status planned">Experimental</span><ArrowIcon /></a>
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
