"""Verify the unchanged Seigyo source snapshot against its import manifest."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'upstream/seigyo-import.json').read_text())
source = root / 'upstream/seigyo'
expected = {entry['path'] for entry in manifest['files']}
actual = {str(path.relative_to(source)) for path in source.rglob('*') if path.is_file()}
errors = []
for entry in manifest['files']:
    path = source / entry['path']
    if not path.is_file():
        errors.append('Missing: ' + entry['path'])
        continue
    data = path.read_bytes()
    if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
        errors.append('Changed: ' + entry['path'])
errors.extend('Unexpected: ' + path for path in sorted(actual - expected))
if errors:
    raise SystemExit('\n'.join(errors))
print(f"Verified {len(expected)} imported files at {manifest['revision']}.")
