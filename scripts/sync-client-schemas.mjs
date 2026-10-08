import { readFile, mkdir, writeFile } from 'node:fs/promises';
const root = new URL('../', import.meta.url);
const schemas = ['envelope.schema.json', 'capability-discovery.schema.json'];
for (const schema of schemas) {
  const source = await readFile(new URL(`specification/draft-01/${schema}`, root));
  for (const dir of ['clients/typescript/schema/', 'clients/elixir/priv/']) {
    const target = new URL(`${dir}${schema}`, root);
    if (process.argv.includes('--check')) {
      if (!source.equals(await readFile(target))) throw new Error(`Schema differs: ${dir}${schema}`);
    } else {
      await mkdir(new URL(dir, root), { recursive: true });
      await writeFile(target, source);
    }
  }
}
console.log('Client schemas match draft-01.');
