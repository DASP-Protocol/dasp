import { execFileSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const root = fileURLToPath(new URL('../', import.meta.url));
const out = join(root, 'dist/client-packages');
const temp = await mkdtemp(join(tmpdir(), 'dasp-package-check-'));
const run = (command, args, cwd) => execFileSync(command, args, { cwd, stdio: 'inherit' });
await mkdir(out, { recursive: true });
try {
  run('node', ['scripts/sync-client-schemas.mjs', '--check'], root);
  const meta = JSON.parse(await readFile(join(root, 'clients/typescript/package.json')));
  const npmArchive = join(out, 'dasp-protocol-client-' + meta.version + '.tgz');
  run('npm', ['pack', '--pack-destination', out], join(root, 'clients/typescript'));
  const ts = join(temp, 'typescript');
  await mkdir(ts);
  await writeFile(join(ts, 'package.json'), JSON.stringify({ private: true, type: 'module' }));
  run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund', npmArchive], ts);
  // Import the public entry point from a consumer outside the repository.
  const example = await readFile(join(root, 'clients/typescript/examples/recorded.mjs'), 'utf8');
  await writeFile(join(ts, 'smoke.mjs'), example.replace('../dist/index.js', '@dasp-protocol/client'));
  run('node', ['smoke.mjs'], ts);
  await writeFile(join(ts, 'consumer.ts'), [
    'import { Client, type Event, type Session, type Transport, type ProfileValidator } from "@dasp-protocol/client";',
    'declare const transport: Transport;',
    'declare const validateProfile: ProfileValidator;',
    'declare const session: Session;',
    'const client = new Client({ source: "urn:client:one", hostSource: "urn:host:one", transport, validateProfile });',
    'const receipt: Promise<Event<"receipt">> = client.submit(session, { command_id: "cmd-1", name: "counter.add", input: { amount: 3 } });'
  ].join('\n'));
  run(join(root, 'clients/typescript/node_modules/.bin/tsc'),
    ['--noEmit', '--strict', '--module', 'NodeNext', '--target', 'ES2022', 'consumer.ts'], ts);

  const hexArchive = join(out, 'dasp_client-' + meta.version + '.tar');
  run('mix', ['hex.build', '--output', hexArchive], join(root, 'clients/elixir'));
  const outer = join(temp, 'hex'), unpacked = join(temp, 'dasp_client'), ex = join(temp, 'elixir');
  for (const dir of [outer, unpacked, ex]) await mkdir(dir);
  run('tar', ['-xf', hexArchive, '-C', outer], temp);
  run('tar', ['-xzf', join(outer, 'contents.tar.gz'), '-C', unpacked], temp);
  await writeFile(join(ex, 'mix.exs'), [
    'defmodule PackageCheck.MixProject do',
    '  use Mix.Project',
    '  def project, do: [app: :package_check, version: "0.0.0", deps: [{:dasp_client, path: "../dasp_client"}]]',
    '  def application, do: [extra_applications: [:crypto]]',
    'end'
  ].join('\n'));
  run('mix', ['deps.get'], ex);
  run('mix', ['run', join(unpacked, 'examples/recorded.exs')], ex);

  const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
  const dirty = execFileSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' }).trim().length > 0;
  const packages = [];
  for (const file of [npmArchive, hexArchive]) packages.push({
    file: file.slice(out.length + 1),
    sha256: createHash('sha256').update(await readFile(file)).digest('hex')
  });
  await writeFile(join(out, 'manifest.json'), JSON.stringify({
    version: meta.version, core: 'draft-01', commit, dirty,
    published: false, license: 'pending', binding: 'application adapter', packages
  }, null, 2) + '\n');
  console.log('Both package archives installed and ran outside the repository.');
} finally {
  await rm(temp, { recursive: true, force: true });
}
