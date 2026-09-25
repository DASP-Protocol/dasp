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
          <p class="hero-tagline">A control protocol for durable actors.</p>
          <p class="hero-description">For agent builders who need commands, saved outcomes, and recovery across languages—without requiring chat or turn semantics in the core.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/guide.html')">Explore the protocol <ArrowIcon /></a>
            <a class="text-link" href="https://github.com/DASP-Protocol/dasp">View on GitHub <ArrowIcon /></a>
          </div>
          <div class="hero-context"><span class="draft-tag"><span class="status-dot"></span> Design draft</span><p class="hero-note">Built from Seigyo. Elixir first. TypeScript next.</p></div>
        </div>
        <ProtocolExplainer kind="actors" />
      </div>
    </section>

    <section class="actor-introduction" aria-labelledby="actor-title">
      <h2 id="actor-title">Actors have work to do.<br>A conversation is optional.</h2>
      <p>An actor accepts intent, manages state, and performs application work. DASP is defining the shared control contract around that work. A profile supplies the application-specific inputs and results; the core does not prescribe a chat interface.</p>
    </section>

    <section class="explanation-row" aria-labelledby="admission-title">
      <div class="explanation-copy">
        <h2 id="admission-title">Accepted does not<br>mean completed.</h2>
        <p>A command carries a stable identity. Its receipt reports admission. A saved outcome tells the client what happened—even when the answer is uncertain.</p>
        <p>Temporary progress helps a client show activity. It cannot prove completion.</p>
        <a class="text-link" :href="link('/protocol/messages.html')">Understand the messages <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="admission" />
    </section>

    <section class="explanation-row recovery-row" aria-labelledby="recovery-title">
      <ProtocolExplainer kind="recovery" />
      <div class="explanation-copy">
        <h2 id="recovery-title">The connection ends.<br>The session continues.</h2>
        <p>A disconnect does not cancel accepted work. Saved updates remain ordered within the session. A returning client reads after its last applied cursor.</p>
        <p>Retry unresolved intent with the same command ID and data. Keep recovery explicit.</p>
        <a class="text-link" :href="link('/protocol/recovery.html')">Read the recovery rules <ArrowIcon /></a>
      </div>
    </section>

    <section class="explanation-row" aria-labelledby="multiplayer-title">
      <div class="explanation-copy">
        <h2 id="multiplayer-title">Many clients.<br>One shared session.</h2>
        <p>Follow the same actor from more than one client. The server controls command admission and shared state. Each client reads the saved updates with its own cursor.</p>
        <p>Multi-user roles, presence, and shared editing are proposed extensions. They are not part of the current contract.</p>
        <a class="text-link" href="https://github.com/DASP-Protocol/dasp/blob/main/upstream/seigyo/docs/seigyo/collaboration.md">Read the collaboration proposal <ArrowIcon /></a>
      </div>
      <ProtocolExplainer kind="multiplayer" />
    </section>

    <section class="contract-section" aria-labelledby="contract-title">
      <div><h2 id="contract-title">Common rules.<br>Native clients.</h2><p>The specification defines the meaning. Each language chooses its API. Shared schemas and conformance checks keep them aligned.</p><a class="text-link" :href="link('/protocol/index.html')">Read the specification <ArrowIcon /></a></div>
      <div class="client-table">
        <a :href="link('/clients/elixir.html')"><span><strong>Elixir</strong><small>Existing Seigyo client · extraction planned</small></span><span class="client-status">Imported</span><ArrowIcon /></a>
        <a :href="link('/clients/typescript.html')"><span><strong>TypeScript</strong><small>Independent client · shared wire contract</small></span><span class="client-status planned">Planned</span><ArrowIcon /></a>
        <div class="client-footnote">No released DASP packages yet. Client status is explicit.</div>
      </div>
    </section>

    <section class="source-section" aria-labelledby="source-title">

      <div class="source-grid"><h2 id="source-title">From Seigyo.<br>Toward a general actor protocol.</h2><div><p>The starting point is Seigyo’s coding profile: its messages, retry rules, saved updates, schemas, and client. DASP is extracting the common contract for use beyond coding agents.</p><p class="source-note">The current binding uses Phoenix Channel WebSocket frames. General actor profiles and DASP naming decisions remain open.</p><a class="text-link" :href="link('/project/decisions.html')">See the decisions ahead <ArrowIcon /></a></div></div>
    </section>

    <section class="start-section" aria-label="Start reading">
      <div><h2>Make the failure cases clear.</h2></div>
      <a class="primary-link" :href="link('/protocol/recovery.html')">Read the recovery rules <ArrowIcon /></a>
    </section>
    <footer class="home-footer"><span>DASP / Durable Actor Session Protocol</span><a :href="link('/brand.html')">Brand &amp; assets <ArrowIcon /></a><a href="https://github.com/DASP-Protocol/dasp">Developed in the open <ArrowIcon /></a></footer>
  </div>
</template>
