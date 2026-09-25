import { readFile, mkdir, writeFile } from 'node:fs/promises';
const root = new URL('../', import.meta.url);
const source = await readFile(new URL('specification/draft-01/envelope.schema.json', root));
for (const dir of ['clients/typescript/schema/', 'clients/elixir/priv/']) {
  const target = new URL(`${dir}envelope.schema.json`, root);
  if (process.argv.includes('--check')) {
    if (!source.equals(await readFile(target))) throw new Error(`Schema differs: ${dir}`);
  } else {
    await mkdir(new URL(dir, root), { recursive: true });
    await writeFile(target, source);
  }
}
console.log('Client schemas match draft-01.');
