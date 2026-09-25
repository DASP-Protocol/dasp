import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = 'website/.vitepress/dist';
function walk(dir) { return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]); }
const files = walk(root);
const htmlFiles = files.filter(f => f.endsWith('.html'));
const ids = new Map(htmlFiles.map(file => [file, new Set([...readFileSync(file, 'utf8').matchAll(/\bid="([^"]+)"/g)].map(m => m[1]))]));
const origin = 'https://dasp-protocol.github.io';
const failures = [];
let checked = 0;
for (const file of htmlFiles) {
  const html = readFileSync(file, 'utf8');
  const relative = path.relative(root, file).split(path.sep).join('/');
  for (const match of html.matchAll(/<(?:a|link|script|img|source)\b[^>]*?\b(?:href|src)="([^"]+)"/g)) {
    const link = match[1].replaceAll('&amp;', '&');
    if (/^(data:|mailto:|tel:)/.test(link)) continue;
    const url = new URL(link, `${origin}/dasp/${relative}`);
    if (url.origin !== origin || !url.pathname.startsWith('/dasp/')) continue;
    let target = decodeURIComponent(url.pathname.slice('/dasp/'.length));
    if (!target || target.endsWith('/')) target += 'index.html';
    if (!path.extname(target)) target += '.html';
    const absolute = path.join(root, target);
    checked++;
    if (!existsSync(absolute)) failures.push(`${relative} -> ${link} (missing file)`);
    else if (url.hash && absolute.endsWith('.html') && !ids.get(absolute)?.has(decodeURIComponent(url.hash.slice(1)))) failures.push(`${relative} -> ${link} (missing anchor)`);
  }
  if (!relative.startsWith('source/') && relative !== '404.html') {
    assert(/rel="canonical"/.test(html), `Missing canonical URL: ${relative}`);
    assert(/property="og:image"/.test(html), `Missing social preview: ${relative}`);
  }
}
assert.equal(failures.length, 0, [...new Set(failures)].join('\n'));
assert(!files.some(file => /concept-/.test(file)), 'Unused logo studies must not ship');
console.log(`Site: ${htmlFiles.length} pages and ${checked} local links/assets/anchors checked.`);
