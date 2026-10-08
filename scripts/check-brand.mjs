import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const expected = 'website/public/brand';
const actual = mkdtempSync(path.join(tmpdir(), 'dasp-brand-'));
try {
  execFileSync(process.execPath, ['scripts/build-brand.mjs', actual], { stdio: 'inherit' });
  const files = readdirSync(expected).sort();
  assert.deepEqual(readdirSync(actual).sort(), files, 'Generated brand asset names differ');
  for (const file of files) {
    const generated = readFileSync(path.join(actual, file));
    if (file.endsWith('.svg')) {
      assert(!/NaN|Infinity/.test(generated.toString()), `Invalid SVG coordinate: ${file}`);
    }
    assert(generated.equals(readFileSync(path.join(expected, file))), `Brand asset differs: ${file}. Run npm run brand:build.`);
  }
  console.log(`Brand: ${files.length} generated assets match the saved assets.`);
} finally {
  rmSync(actual, { recursive: true, force: true });
}
