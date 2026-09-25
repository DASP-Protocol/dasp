# Seigyo Protocol verification

The [requirement matrix](verification-matrix.json) maps 70 current requirements
to reviewed assertions. It includes one explicit exclusion: shared documents
are not enabled in coding v1. Proposed Work, collaboration, and topology
documents are outside this release. Matrix tests detect missing rows and
missing evidence files. They do not prove that an assertion is correct.

The report does not claim full production conformance. Test skips, coverage
gaps, deployment requirements, and fixture limits remain visible below.

## Execution report

Each unit has one focused commit. Each changed package passed its format and
compile checks. The test counts below record the full suite run for that unit;
later rows replace earlier evidence when they test the same package again.
The frozen coding v1 digest remains
`772c344d263f7cf35ba49c01040832192e75324001e75ad5409f57ae78aacb56`.
The approved S05 initialization grammar is a separate opt-in contract.

| Unit and commit | Full suite evidence | Gaps at that point |
| --- | --- | --- |
| S01 `6d5a2c1` — freeze coding v1 | Protocol 80; Acceptance 78; kernel coverage 100% | One optional live SmolBox skip |
| S02 `2e8d79b` — share definitions | Protocol 87; Web 27; Acceptance 78; kernel coverage 100% | One optional live SmolBox skip |
| S03 `357a53c` — enforce message roles | Protocol 90; Web 29; Acceptance 84; kernel coverage 100% | One optional live SmolBox skip |
| S04 `72827aa` — preserve decisions and confirm settlement | Session 22; Server 83; Acceptance 91 | Two Server database skips; one SmolBox skip; Session coverage 72.40% below 90% |
| S05 `68a3a6c` — negotiate and retain contracts | Protocol 99; Session 23; Storage 8; Server 83; Web 29; Acceptance 100; kernel coverage 100% | Six Storage and two Server database skips; one SmolBox skip |
| S06 `d611045` — validate replay and acknowledge application | Protocol 106; Server 85; Web 29; Acceptance 112; kernel coverage 100% | Two database skips; one SmolBox skip; first client-isolation run failed, focused and full reruns passed |
| S07 `12b9da7` — retain Session meaning | Session 23; Storage 8; Server 85; Acceptance 117 | Seven Storage and two Server database skips; one SmolBox skip; Session coverage 72.80% below 90% |
| S08 `8bc32ea` — bound work and declare loss | Protocol 106; Server 88; Web 30; Acceptance 122 at concurrency 4; kernel coverage 100% | Two database skips; one SmolBox skip; concurrency 20 fixture failures remain |
| S09 — this report's commit | Python 21; Protocol 106; Storage 16; Server 90; Acceptance 126 at concurrency 4; both external consumers; kernel coverage 100% | One SmolBox skip; Storage coverage 64.58% below 90%; earlier Session coverage and concurrency limits remain |

S09 used PostgreSQL 18 in an isolated local cluster. All eight PostgreSQL
Storage tests and both PostgreSQL Server tests ran and passed. The final
acceptance run enabled the external Elixir consumer and wrote the
[Python report](verification-result.json). That report labels the pending
S09 work with its parent revision and `+working-tree`; it does not claim to
have tested a clean checkout of the parent commit.

The Storage coverage command passed all 16 tests but exited with a failed
coverage gate. The earlier Session coverage command also failed its gate.
These are separate from the passing kernel metric, which excludes client
transport code. No threshold was lowered. The unchanged Web package retains
its S08 result. Local dependency warnings remain outside this change.

## Independent evidence

Ordinary scenarios use `Jido.Seigyo.Client`. Runtime setup and fault controls
stay in acceptance fixtures. The raw Elixir verifier reads published JSON
and checks the live operation surface without the typed client or protocol
decoder. Hand-written negative frames include wrong roles, internal routes,
forged trace authority, invalid references, and wrong versions. A controlled
WebSocket peer sends malformed Results and Replies to the typed client.

The Python verifier uses only copied published artifacts and the standard
library. It does not import Elixir code, read a Store, or inspect an Agent.
It checks initialization, open, admission, reconnect, duplicate submission,
paginated replay, Result identity, and immutable repeated reads. Its JSON
report records contract digest, profile, binding, supplied implementation
revision, passes, failures, and skips. The revision is an operator-supplied
label, not a server attestation. The fixture records the checked-out revision
with `+working-tree` when it tests the pending work.

This verifier checks eight Signal types used by its journey and rejects
unsupported types. It is not a complete alternate SDK. It enforces custom
UTF-8 and encoded JSON limits, portable numeric values, identity patterns,
page continuity and cursor identity, Result status/error relationships,
reasoning visibility, usage measurement, and the Result block cost budget.
Its schema interpreter rejects unknown keywords. A deliberate schema-only
decoder defect accepts an invalid uncertain Result; the independent semantic
check rejects it. Mutated bundle bytes and forged indexes also fail.

The focused tests cover 500 generated IDs, safe integer boundaries, malformed
UTF-8, Unicode byte edges, closed unions, Result state combinations, duplicate
JSON keys, WebSocket fragmentation and overflow, and every tested replay page
split. A public retry case preserves different Unicode spellings, whitespace,
and absent versus empty input. Concurrent admission and mutation cases test
one saved decision. These finite cases do not claim exhaustive correctness.

## Run the Python verifier outside the repository

Copy these files from `apps/jido_code_acceptance/scripts` to an empty directory:
`verify_contract.py`, `seigyo_v1.py`, `seigyo_socket.py`, and `verify_endpoint.py`.
Copy the immutable `apps/jido_seigyo/priv/seigyo/coding-v1` directory as
`contract`, and copy `priv/seigyo/initialization-v1/schemas.json` from the
Seigyo package as `initialization.json`. Use Python 3.9 or later.

Set `SEIGYO_TOKEN` from the endpoint's credential source. The script does not
accept a token argument or print the token. Use a test endpoint: this journey
creates a Session and submits one brief model request.

```sh
python3 -B verify_endpoint.py \
  --contract contract --initialization-schema initialization.json \
  --digest 772c344d263f7cf35ba49c01040832192e75324001e75ad5409f57ae78aacb56 \
  --url "$SEIGYO_URL" --implementation-revision "$SERVER_REVISION"
```

The default deadline is 30 seconds per connection. `--timeout` permits at most
300 seconds. The WebSocket implementation uses TLS verification for `wss`,
masked client frames, bounded headers and messages, and an absolute read
deadline. It permits no compression or unrequested extensions. It sends no
authorization data in Trace fields. It does not require a local Workspace.

## Run the Elixir consumer

The [standalone example](../../apps/jido_seigyo/examples/standalone/README.md)
is a small independent Mix project. Copy it outside the umbrella, set the
Seigyo and local Signal V3 paths, then fetch dependencies and compile there.
Its build and dependency directories belong to that consumer. The acceptance
test starts the resulting BEAM files in a separate Elixir process with only
the consumer's `ebin` paths. The script fails if Server, Jido AI, AgentServer,
or the Phoenix endpoint is available. It completes a real client journey.

To repeat both external consumer proofs against fixture endpoints:

```sh
cd apps/jido_code_acceptance
SEIGYO_EXTERNAL_CONSUMER=/absolute/path/to/built/consumer \
  mix test test/external_consumers_test.exs
```

Without this variable, the external Elixir case is an explicit skip. The
Python proof still copies its files to a temporary directory and runs there.
Set `SEIGYO_VERIFICATION_REPORT` to a report file path to keep its JSON result.

## Validation boundaries

Run Mix commands one at a time because umbrella apps share build paths.
Run the full acceptance suite with `--max-cases 4` on this host. Scenarios still
exercise concurrent clients and writers. At concurrency 20, existing fixture
failures occurred in client isolation and file-home setup. File storage uses
a conservative hashed loopback-port lock; a port collision rejects startup.
These higher-concurrency failures are not claimed to be fixed.

The S09 PostgreSQL race test first failed against the prior adapter: both
Sessions committed one configuration Mutation ID. The corrected adapter reads
that Store-wide ID again inside its mutation lock. It no longer depends on
the first 1,001 configuration events from just the requested Session. The
same lookup serves saved decision reads. The test database is an isolated
local PostgreSQL cluster, not an existing user database.

The optional live SmolBox test requires an approved runtime artifact. Fake
Sandbox tests do not prove the live VM environment. File restart tests prove
process recovery, not power-loss durability. Provider parity uses MockLLM
HTTP fixtures and does not prove external-provider uptime. Reserved Artifact
output blocks, timed content expiry, and alternate transports are not advertised.

Kernel coverage excludes transport client modules. Session and Storage
coverage are separate metrics and can remain below their configured gates
even when behavior tests pass. The execution report must state those failures;
do not lower a threshold or present a skip as a pass.
