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
| ART-LIVE-TRACE | Recorded head capture, confirmation races, equal and conflicting opens, fixed-boundary pages, resync, cancelled pages/failures, and open timeout examples are consistent; changed traces fail |
| ART-IDENTITY | Published schema and example bytes match their SHA-256 manifest |
| ART-ENCRYPTED-SHAPES | Carrier/header shapes, exact raw integer tokens, permitted Unicode, duplicate header keys, canonical base64url, selected decoded bounds, and matching metadata |
| ART-AUTHORITY | Signed grant bytes, closed schemas, scope and time examples, recorded cross-session admissions, equal retries, budgets, and enumerated serial commit orders |

Run all project checks with `npm run check`. This adds public-source checks, the production site build, and internal link and anchor checks.

## Limits

The invalid-event vectors contain parsed JSON. They cannot test a parser's rejection of duplicate keys or invalid UTF-8. The trace checker compares expected records; it is not a host or a durable client implementation.

The WebSocket transcript check separates recorded host head capture from reply receipt. It checks the saved session tuple, optional session subject, distinct event identity, selected counter payloads, and retained recovery targets. Its continuity rejection case keeps the captured head and reply equal, so another head check cannot hide a missing continuity guard. It does not open a socket, race real commits, persist a client checkpoint, or execute permissions and queue limits. Those observations remain runtime cases.

Encrypted carrier fixtures use synthetic ciphertext and signatures. The [raw header vectors](fixtures/encrypted-header-vectors.json) test exact number tokens, escaped duplicate keys, prohibited characters, and protected-header UTF-8. The bounded header helper handles this closed header only; it is not a general JSON parser or wire receiver. The suite does not test outer wire duplicate keys or original incoming-message size, cryptography, setup, peer trust, record consumption, or output queue races. See the [binding contract and its release requirements](../docs/specification/payload-encryption.md).

Use [behavioral cases](behavioral-cases.md) when building a runtime harness. Keep unsupported cases marked not executed rather than treating them as a pass.

Authority fixtures use a public test key and valid Ed25519 signatures checked by one Node crypto implementation. The grant parser checks raw signed JSON vectors. The serial decision evaluator checks recorded results and possible commit orders; it is not a host transaction engine. It does not test actual races, storage/restart, issuer administration, output release, or encrypted exchanges. The plaintext-shape check confirms that the required scalar extension fits the existing core event and cannot be added to the encrypted outer carrier. Independent signature acceptance, complete authenticated setup, and runtime evidence remain release requirements.
