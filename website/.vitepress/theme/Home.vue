<script setup>
import { withBase } from 'vitepress';
import ArrowIcon from './ArrowIcon.vue';
const link = (p) => withBase(p);
</script>

<template>
  <div class="dasp-home">
    <section class="intro" aria-labelledby="hero-title">
      <div class="hero-grid">
        <div class="hero-copy">
          <h1 id="hero-title">Durable Actor<br>Session Protocol</h1>
          <p class="hero-tagline">The connection ends. The session continues.</p>
          <p class="hero-description">A shared protocol for commands, saved outcomes, and recovery. Connect to durable actors across languages. Pick up where you left off.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/guide.html')">Explore the protocol <ArrowIcon /></a>
            <a class="text-link" href="https://github.com/DASP-Protocol/dasp">View on GitHub <ArrowIcon /></a>
          </div>
          <div class="hero-context"><span class="draft-tag"><span class="status-dot"></span> Design draft</span><p class="hero-note">Built from Seigyo. Elixir first. TypeScript next.</p></div>
        </div>
        <figure class="session-diagram" aria-label="A client submits a command, disconnects, and resumes from a saved update cursor. The actor continues its work.">
          <figcaption class="diagram-header">A session across two connections</figcaption>
          <div class="lane-labels"><span>Client</span><span>Actor session</span></div>
          <div class="diagram-body">
            <div class="client-line"></div><div class="actor-line"></div>
            <div class="flow-row row-command"><span class="flow-label">submit command</span><i></i><b></b></div>
            <div class="flow-row row-receipt reverse"><span class="flow-label">admission receipt</span><i></i><b></b></div>
            <div class="disconnect"><span>connection lost</span></div>
            <div class="saved-work"><span class="small-dot"></span> work continues<br><span class="saved-sub">outcome saved</span></div>
            <div class="flow-row row-resume"><span class="flow-label">resume after cursor</span><i></i><b></b></div>
            <div class="flow-row row-updates reverse"><span class="flow-label">replay saved updates</span><i></i><b></b></div>
          </div>
          <div class="diagram-footer"><span class="small-dot"></span> Same session. Same command identity.</div>
        </figure>
      </div>
    </section>

    <section class="principles" aria-label="Protocol principles">
      <article><h2>Intent has an identity.</h2><p>Retry a command with the same ID and data. A lost reply must not create new work.</p></article>
      <article><h2>Saved facts come first.</h2><p>Receipts report admission. Saved outcomes establish what happened. Progress stays temporary.</p></article>
      <article><h2>Recovery is part of the contract.</h2><p>Apply ordered updates. Save the cursor. Resume from that point after a connection fails.</p></article>
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
    <footer class="home-footer"><span>DASP / Durable Actor Session Protocol</span><a href="https://github.com/DASP-Protocol/dasp">Developed in the open <ArrowIcon /></a></footer>
  </div>
</template>
