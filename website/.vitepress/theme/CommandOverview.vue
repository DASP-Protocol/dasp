<template>
  <div class="operations">
    <table>
      <caption>Five client operations · short message names</caption>
      <thead><tr><th scope="col">Purpose</th><th scope="col">Request</th><th scope="col">Reply</th></tr></thead>
      <tbody>
        <tr><td>Open or return to a session</td><td><code>session.open</code></td><td><code>session.opened</code></td></tr>
        <tr><td>Ask the actor to do work</td><td><code>command</code></td><td><code>receipt</code></td></tr>
        <tr><td>Read current saved state</td><td><code>view.read</code></td><td><code>view</code></td></tr>
        <tr><td>Read missed events</td><td><code>updates.read</code></td><td><code>updates</code></td></tr>
        <tr><td>Check a command's result</td><td><code>outcome.read</code></td><td><code>outcome</code></td></tr>
      </tbody>
    </table>
  </div>
</template>
<style scoped>
.operations { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; text-align: left; font-size: 14px; }
caption { text-align: left; color: var(--vp-c-text-2); font-size: 12px; padding: 12px 0; }
th, td { padding: 14px 16px; border-bottom: 1px solid var(--vp-c-divider); }
code { white-space: nowrap; color: var(--vp-c-brand-1); }
</style>
