import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import assert from 'node:assert/strict';

const git = args => execFileSync('git', args, { encoding: 'utf8' }).trim();
assert.equal(path.resolve(git(['rev-parse', '--show-toplevel'])), process.cwd(), 'Run at the public repository root');
assert.equal(git(['status', '--porcelain']), '', 'Commit the reviewed files before preparing a bundle');
assert(existsSync('LICENSE'), 'Select and add the project LICENSE before preparing a release bundle');
const release = JSON.parse(readFileSync('specification/release.json'));
assert(/^\d+\.\d+\.\d+-draft\.\d+$/.test(release.version), 'Expected a review draft publication version');
const commit = git(['rev-parse', 'HEAD']);
const name = `dasp-${release.version}`;
const output = path.resolve('dist/releases');
const directory = path.join(output, name);
assert(!existsSync(directory), `Bundle already exists at ${directory}; preserve it or move it before preparing another candidate`);
mkdirSync(output, { recursive: true });
const sourceArchive = execFileSync('git', ['archive', '--format=tar', `--prefix=${name}/`, 'HEAD'], { maxBuffer: 128 * 1024 * 1024 });
execFileSync('tar', ['-xf', '-', '-C', output], { input: sourceArchive });
const report = readFileSync('dist/conformance-report.json');
writeFileSync(path.join(directory, 'conformance-report.json'), report);
const files = {};
const tracked = git(['ls-files', '-z']).split('\0').filter(Boolean).sort();
for (const file of [...tracked, 'conformance-report.json'].sort()) {
  files[file] = createHash('sha256').update(readFileSync(path.join(directory, file))).digest('hex');
}
const manifest = {
  publicationVersion: release.version, core: release.core, suite: release.suite,
  status: 'prepared-locally', sourceCommit: commit, sourceDate: git(['show', '-s', '--format=%cI', 'HEAD']),
  algorithm: 'sha256', files,
  evidence: 'Artifact checks only. No runtime implementation conformance is claimed.'
};
writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
const archive = path.join(output, `${name}.tar.gz`);
execFileSync('tar', ['-czf', archive, '-C', output, name], { env: { ...process.env, COPYFILE_DISABLE: '1' } });
const hash = createHash('sha256').update(readFileSync(archive)).digest('hex');
writeFileSync(archive + '.sha256', `${hash}  ${path.basename(archive)}\n`);
console.log(`Prepared ${archive}\nSource commit: ${commit}\nNo Git tag or remote release was created.`);
