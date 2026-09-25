import { mkdir, readFile, writeFile, cp } from 'node:fs/promises';
import path from 'node:path';

const root = process.cwd();
const repository = 'https://github.com/DASP-Protocol/dasp/blob/main/';
const files = {
  'docs/specification/README.md': 'protocol/index.md',
  'docs/specification/cloudevents.md': 'protocol/cloudevents.md',
  'docs/specification/profiles-and-bindings.md': 'protocol/profiles-and-bindings.md',
  'docs/design/seigyo-mapping.md': 'project/seigyo-mapping.md',
  'docs/specification/messages.md': 'protocol/messages.md',
  'docs/specification/recovery.md': 'protocol/recovery.md',
  'docs/specification/security-and-versioning.md': 'protocol/security-and-versioning.md',
  'docs/specification/example.md': 'protocol/example.md',
  'docs/design/decisions.md': 'project/decisions.md',
  'docs/design/ahp-reference.md': 'project/ahp-reference.md',
  'clients/README.md': 'clients/index.md',
  'clients/elixir/README.md': 'clients/elixir.md',
  'clients/typescript/README.md': 'clients/typescript.md',
  'conformance/README.md': 'conformance/index.md',
  'upstream/README.md': 'source/index.md'
};
for (const [source, destination] of Object.entries(files)) {
  let text = await readFile(path.join(root, source), 'utf8');
  text = text.replace(/\]\(([^)]+)\)/g, (match, target) => {
    if (/^(https?:|mailto:|#)/.test(target)) return match;
    const [file, fragment] = target.split('#');
    const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(source), file));
    const mapped = files[resolved];
    const link = mapped
      ? path.posix.relative(path.posix.dirname(destination), mapped).replace(/\.md$/, '.html')
      : repository + resolved;
    return `](${link}${fragment ? '#' + fragment : ''})`;
  });
  const output = path.join(root, 'website', destination);
  await mkdir(path.dirname(output), { recursive: true });
  await writeFile(output, `---\neditLink: false\n---\n\n${text}`);
}
console.log(`Generated ${Object.keys(files).length} site pages from project documents.`);

await mkdir('website/public/schemas', { recursive: true });
await cp('specification/draft-01', 'website/public/schemas/draft-01', { recursive: true });
