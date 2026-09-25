import { existsSync, readFileSync, lstatSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { pages, artifacts, generatedDirectories } from './site-map.mjs';

const roots = new Set(['.github', 'assets', 'clients', 'conformance', 'docs', 'scripts', 'specification', 'website']);
const rootFiles = new Set(['.gitignore', 'README.md', 'CONTRIBUTING.md', 'SECURITY.md', 'RELEASING.md', 'CHANGELOG.md', 'LICENSE', 'NOTICE', 'package.json', 'package-lock.json', 'manifest.json', 'conformance-report.json']);
let candidates;
if (!existsSync('.git') && existsSync('manifest.json')) {
  const manifest = JSON.parse(readFileSync('manifest.json'));
  for (const [file, hash] of Object.entries(manifest.files)) {
    assert(!path.isAbsolute(file) && !file.split('/').includes('..'), `Invalid manifest path: ${file}`);
    assert.equal(createHash('sha256').update(readFileSync(file)).digest('hex'), hash, `Bundle digest mismatch: ${file}`);
  }
  candidates = [...Object.keys(manifest.files), 'manifest.json'];
} else {
  candidates = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8' }).split('\0').filter(Boolean);
}

const files = [...new Set(candidates)].filter(file => existsSync(file));
for (const file of files) {
  assert(!lstatSync(file).isSymbolicLink(), `Public inputs cannot be symlinks: ${file}`);
  assert(rootFiles.has(file) || (file.includes('/') && roots.has(file.split('/')[0])), `Unexpected public root: ${file}`);
  assert(!/(^|\/)(node_modules|\.agents|\.codex|archive|planning|research|upstream)(\/|$)/.test(file), `Local material in public inputs: ${file}`);
  assert(!file.startsWith('docs/design/'), `Working design notes belong outside the repository: ${file}`);
  if (file.startsWith('website/')) {
    assert(!generatedDirectories.some(dir => file.startsWith(`website/${dir}/`)), `Generated page is tracked: ${file}`);
    assert(!/^website\/public\/(schemas|fixtures)\//.test(file), `Generated download is tracked: ${file}`);
    assert(file !== 'website/guide.md', 'Compatibility page must be generated');
  }
}
for (const file of [...Object.keys(pages), ...Object.keys(artifacts)]) assert(existsSync(file), `Missing public source: ${file}`);
const definitions = JSON.parse(readFileSync('conformance/requirements.json')).requirements;
const report = JSON.parse(readFileSync('dist/conformance-report.json'));
const testIds = new Set(report.results.map(result => result.id));
const ids = new Set();
for (const requirement of definitions) {
  assert(!ids.has(requirement.id), `Duplicate requirement: ${requirement.id}`); ids.add(requirement.id);
  const text = readFileSync(requirement.document, 'utf8');
  assert(text.includes(`{#${requirement.anchor}}`) || text.includes(`id="${requirement.anchor}"`), `Missing requirement anchor: ${requirement.id}`);
  assert(text.includes(requirement.id), `Missing requirement text: ${requirement.id}`);
  for (const test of requirement.artifactCases) assert(testIds.has(test), `Unknown case: ${test}`);
  assert.equal(requirement.runtime, 'not-executed', 'No runtime runner is implemented yet');
  for (const test of requirement.runtimeCases) assert(readFileSync('conformance/behavioral-cases.md', 'utf8').includes(`## ${test}:`), `Unknown runtime case: ${test}`);
}
const actualIds = new Set();
for (const file of Object.keys(pages).filter(p => p.startsWith('docs/specification/') && !p.endsWith('README.md') && !p.endsWith('example.md'))) {
  for (const match of readFileSync(file, 'utf8').matchAll(/(?:\{#|id=")(dasp-[a-z]+-\d{3})/g)) actualIds.add(match[1].toUpperCase());
}
assert.deepEqual([...actualIds].sort(), [...ids].sort(), 'Requirement index must cover all normative anchors');
// Check local Markdown file targets as well as generated website links.
for (const file of files.filter(f => f.endsWith('.md'))) {
  const text = readFileSync(file, 'utf8');
  for (const match of text.matchAll(/\]\(([^)]+)\)/g)) {
    const link = match[1];
    if (/^(https?:|mailto:|#|\/)/.test(link)) continue;
    const target = path.resolve(path.dirname(file), link.split('#')[0]);
    assert(target.startsWith(process.cwd() + path.sep), `Link leaves public project: ${file} -> ${link}`);
    assert(existsSync(target), `Broken source link: ${file} -> ${link}`);
  }
}
const home = readFileSync('website/.vitepress/theme/Home.vue', 'utf8');
assert(!/github\.com\/[^\s"']+\/blob\/main\/(upstream|reference)\//.test(home));
console.log(`Publication inputs: ${files.length} files and ${ids.size} requirement groups checked.`);
