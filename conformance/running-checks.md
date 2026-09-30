# Run the draft checks

Use Node.js 22 or later. No actor runtime is needed for artifact checks.

```sh
npm ci
npm run spec:check
```

The suite reports valid events, rejected vectors, recorded trace events, and case groups. It writes `dist/conformance-report.json`. A failure exits with a nonzero status and identifies the failed expectation.

## Case groups

| ID | Check |
| --- | --- |
| ART-SHAPES | All 14 core types have valid event examples |
| ART-NEGATIVE | Reusable invalid event vectors are rejected |
| ART-EXTENSIONS | Optional scalar CloudEvents extensions remain valid |
| ART-RELATIONS | Counter fixtures preserve identity, sequence, and outcome relationships |
| ART-PROFILE | Counter payloads match the illustrative profile |
| ART-TRACE | The recorded retry and replay trace is consistent; changed traces fail |
| ART-IDENTITY | Published schema and example bytes match their SHA-256 manifest |
| ART-ENCRYPTED-SHAPES | Proposed carrier/header shapes, canonical base64url, selected decoded byte bounds, and matching outer metadata |

Run all project checks with `npm run check`. This adds public-source checks, the production site build, and internal link and anchor checks.

## Limits

The invalid-event vectors contain parsed JSON. They cannot test a parser's rejection of duplicate keys or invalid UTF-8. The trace checker compares expected records; it is not a host or a durable client implementation.

Encrypted carrier fixtures use synthetic ciphertext and signatures. Their artifact check tests protected-header UTF-8 and encoding, not cryptography, duplicate-key parsing, setup, peer trust, or a live receiver. See the [proposed binding and its review gates](../docs/specification/payload-encryption.md).

Use [behavioral cases](behavioral-cases.md) when building a runtime harness. Keep unsupported cases marked not executed rather than treating them as a pass.
