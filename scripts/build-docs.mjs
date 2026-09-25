import { mkdir, readFile, writeFile, cp, rm } from 'node:fs/promises';
import path from 'node:path';
import { pages, artifacts, aliases, generatedDirectories } from './site-map.mjs';

const repository = 'https://github.com/DASP-Protocol/dasp/blob/main/';
// Only these dedicated generated directories are removed. Authored theme/brand files are preserved.
for (const directory of generatedDirectories) await rm(path.join('website', directory), { recursive: true, force: true });
for (const directory of ['schemas', 'fixtures']) await rm(path.join('website/public', directory), { recursive: true, force: true });
const requirements = JSON.parse(await readFile('conformance/requirements.json', 'utf8')).requirements;
for (const [source, destination] of Object.entries(pages)) {
  let text = await readFile(source, 'utf8');
  if (source === 'conformance/README.md') {
    const rows = requirements.map(r => `| [${r.id}](../${r.document}#${r.anchor}) | ${r.title} | ${r.artifactCases.join(', ') || 'None'} | ${r.runtimeCases.join(', ') || 'Not specified'} — not executed |`);
    text = text.replace('<!-- REQUIREMENT_COVERAGE -->', '## Requirement index\n\nAll artifact links below indicate partial example coverage only.\n\n| Requirement | Scope | Artifact cases | Runtime cases |\n| --- | --- | --- | --- |\n' + rows.join('\n'));
  }
  text = text.replace(/\]\(([^)]+)\)/g, (match, target) => {
    if (/^(https?:|mailto:|#)/.test(target)) return match;
    const [file, fragment] = target.split('#');
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(source), file));
    let link;
    if (pages[resolved]) link = '/' + pages[resolved].replace(/index\.md$/, '').replace(/\.md$/, '.html');
    else if (artifacts[resolved]) link = '/' + artifacts[resolved];
    else link = repository + resolved;
    return `](${link}${fragment ? '#' + fragment : ''})`;
  });
  const paragraph = text.split('\n\n').find(p => !p.startsWith('#') && !p.startsWith('**') && !p.startsWith('Requirement')) || 'DASP protocol documentation.';
  const description = paragraph.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').replace(/[*`]/g, '').replace(/\s+/g, ' ').slice(0, 180);
  const output = path.join('website', destination);
  await mkdir(path.dirname(output), { recursive: true });
  const fm = `---\ndescription: ${JSON.stringify(description)}\neditLink: false\n---\n\n`;
  await writeFile(output, fm + text);
}
for (const [source, destination] of Object.entries(artifacts)) {
  const output = path.join('website/public', destination);
  await mkdir(path.dirname(output), { recursive: true });
  await cp(source, output);
}
for (const [alias, target] of Object.entries(aliases)) {
  const link = '/' + target.replace(/index\.md(?=#|$)/, '').replace(/\.md(?=#|$)/, '.html');
  const output = path.join('website', alias);
  await mkdir(path.dirname(output), { recursive: true });
  await writeFile(output, `---\nlayout: page\nsearch: false\nsidebar: false\ncanonicalPath: ${JSON.stringify(link)}\n---\n\n# Documentation moved\n\n[Continue to the current DASP documentation](${link}).\n`);
}
console.log(`Generated ${Object.keys(pages).length} documentation pages, ${Object.keys(aliases).length} compatibility pages, and ${Object.keys(artifacts).length} downloads.`);
