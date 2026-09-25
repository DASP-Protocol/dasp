"""Check a Seigyo release without Elixir modules or the typed client.

Usage: python3 verify_contract.py PATH [--digest TRUSTED_DIGEST]
The expected digest must come from a trusted source when authenticity matters.
"""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys


def verify(root, expected_digest=None):
    contract = json.loads((root / "contract.json").read_bytes())
    if set(contract) != {"algorithm", "protocol", "profile", "binding", "files", "digest"}:
        raise ValueError("invalid contract fields")
    if contract["algorithm"] != "seigyo-sha256-file-index-v1":
        raise ValueError("unsupported digest algorithm")
    index = {key: value for key, value in contract.items() if key != "digest"}
    encoded = json.dumps(index, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    digest = hashlib.sha256(encoded.encode("ascii")).hexdigest()
    if digest != contract["digest"] or (expected_digest and digest != expected_digest):
        raise ValueError("contract digest mismatch")

    names = [entry["path"] for entry in contract["files"]]
    if names != sorted(set(names)) or not names:
        raise ValueError("file paths must be sorted, unique, and nonempty")
    for entry in contract["files"]:
        if set(entry) != {"path", "bytes", "sha256"}:
            raise ValueError("invalid file entry")
        name = entry["path"]
        path = PurePosixPath(name)
        if (not name.isascii() or path.is_absolute() or ".." in path.parts
                or "\\" in name or str(path) != name
                or name in {"contract.json", "provenance.json"}):
            raise ValueError("invalid normative path")
        target = root / name
        if not target.resolve().is_relative_to(root.resolve()):
            raise ValueError("normative path escapes the bundle")
        content = target.read_bytes()
        if len(content) != entry["bytes"] or hashlib.sha256(content).hexdigest() != entry["sha256"]:
            raise ValueError("normative file mismatch: " + name)
    return contract


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--digest")
    args = parser.parse_args()
    try:
        result = verify(args.path, args.digest)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    print(result["profile"] + " " + result["binding"] + " " + result["digest"])
