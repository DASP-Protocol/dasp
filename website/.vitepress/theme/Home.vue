<script setup>
import { withBase } from 'vitepress';
const link = (p) => withBase(p);
</script>

<template>
  <main class="dasp-home">
    <section class="intro" aria-labelledby="hero-title">
      <div class="eyebrow"><span class="status-dot"></span> DURABLE ACTOR SESSION PROTOCOL <span class="draft-tag">DESIGN DRAFT</span></div>
      <div class="hero-grid">
        <div class="hero-copy">
          <h1 id="hero-title">The connection ends.<br><em>The session continues.</em></h1>
          <p class="hero-description">A shared protocol for commands, saved outcomes, and recovery. Connect to durable actors across languages. Pick up where you left off.</p>
          <div class="hero-actions">
            <a class="primary-link" :href="link('/guide.html')">Explore the protocol <span aria-hidden="true">↗</span></a>
            <a class="text-link" href="https://github.com/DASP-Protocol/dasp">View on GitHub <span aria-hidden="true">↗</span></a>
          </div>
          <p class="hero-note">Built from Seigyo. Elixir first. TypeScript next.</p>
        </div>
        <div class="session-diagram" aria-label="A client submits a command, disconnects, and resumes from a saved update cursor. The actor continues its work.">
          <div class="diagram-header"><span>01 / CONNECTION ≠ SESSION</span><span class="mini-status">SAVED STATE</span></div>
          <div class="lane-labels"><span>CLIENT</span><span>ACTOR SESSION</span></div>
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
        </div>
      </div>
    </section>

    <section class="principles" aria-label="Protocol principles">
      <article><span class="section-number">01</span><h2>Intent has an identity.</h2><p>Retry a command with the same ID and data. A lost reply must not create new work.</p></article>
      <article><span class="section-number">02</span><h2>Saved facts come first.</h2><p>Receipts report admission. Saved outcomes establish what happened. Progress stays temporary.</p></article>
      <article><span class="section-number">03</span><h2>Recovery is part of the contract.</h2><p>Apply ordered updates. Save the cursor. Resume from that point after a connection fails.</p></article>
    </section>

    <section class="contract-section" aria-labelledby="contract-title">
      <div><div class="eyebrow">ONE CONTRACT / MANY IMPLEMENTATIONS</div><h2 id="contract-title">Common rules.<br>Native clients.</h2><p>The specification defines the meaning. Each language chooses its API. Shared schemas and conformance checks keep them aligned.</p><a class="text-link" :href="link('/protocol/index.html')">Read the specification <span aria-hidden="true">→</span></a></div>
      <div class="client-table">
        <a :href="link('/clients/elixir.html')"><span class="language-number">01</span><span><strong>Elixir</strong><small>Existing Seigyo client · extraction planned</small></span><span class="client-status">IMPORTED</span><span aria-hidden="true">↗</span></a>
        <a :href="link('/clients/typescript.html')"><span class="language-number">02</span><span><strong>TypeScript</strong><small>Independent client · shared wire contract</small></span><span class="client-status planned">PLANNED</span><span aria-hidden="true">↗</span></a>
        <div class="client-footnote">No released DASP packages yet. Client status is explicit.</div>
      </div>
    </section>

    <section class="source-section" aria-labelledby="source-title">
      <div class="eyebrow">A SOURCE TO BUILD ON</div>
      <div class="source-grid"><h2 id="source-title">From Seigyo.<br>Toward a general actor protocol.</h2><div><p>The starting point is Seigyo’s coding profile: its messages, retry rules, saved updates, schemas, and client. DASP is extracting the common contract for use beyond coding agents.</p><p class="source-note">The current binding uses Phoenix Channel WebSocket frames. General actor profiles and DASP naming decisions remain open.</p><a class="text-link" :href="link('/project/decisions.html')">See the decisions ahead <span aria-hidden="true">→</span></a></div></div>
    </section>

    <section class="start-section" aria-label="Start reading">
      <div><div class="eyebrow">START WITH THE CONTRACT</div><h2>Make the failure cases clear.</h2></div>
      <a class="primary-link" :href="link('/protocol/recovery.html')">Read the recovery rules <span aria-hidden="true">↗</span></a>
    </section>
    <footer class="home-footer"><span>DASP / Durable Actor Session Protocol</span><a href="https://github.com/DASP-Protocol/dasp">Developed in the open <span aria-hidden="true">↗</span></a></footer>
  </main>
</template>
