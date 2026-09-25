# Elixir client

Experimental `dasp_client`, version `0.1.0-draft.1`, for DASP `draft-01`. Requires Elixir 1.18 or later. No Hex release is published. The project license is pending.

## Install from a local checkout

Add a path dependency to your application's `mix.exs`:

```elixir
{:dasp_client, path: "/absolute/path/to/dasp/clients/elixir"}
```

Then run `mix deps.get`. From the package directory, run `mix test` to use the shared repository fixtures. Build a review archive with `mix hex.build --output /absolute/path/to/dasp_client.tar`. CI also provides archives as [workflow artifacts](https://github.com/DASP-Protocol/dasp/actions/workflows/clients.yml).

## Connect an application

```elixir
{:ok, client} = DASP.Client.new(
  source: "urn:example:client:one",
  host_source: "urn:example:host:one",
  transport: &MyApp.DASPTransport.request/2,
  validate_profile: &MyApp.CounterProfile.valid_event?/1,
  timeout: 10_000
)
session = %{
  "session_id" => "session-counter",
  "actor_id" => "counter-main",
  "profile" => %{"id" => "urn:example:dasp:counter", "version" => "1"}
}
{:ok, _opened} = DASP.Client.open(client, session)

# Save this identity and exact input before the first attempt.
command = %{"command_id" => "command-add-1", "name" => "counter.add", "input" => %{"amount" => 3}}
{:ok, receipt} = DASP.Client.submit(client, session, command)
# The receipt is not a completed outcome.
{:ok, outcome} = DASP.Client.read_outcome(client, session, command["command_id"])
```

Your transport implements `request(json, timeout_ms)` and returns `{:ok, json}` or `{:error, reason}`. It supplies the authenticated channel, binding selection, and framing. Return the complete UTF-8 reply. Do not decode it first: that can discard duplicate keys or number precision.

The callback runs in a monitored worker. A deadline stops that worker and returns a timeout. The adapter must close its I/O resources when the worker stops. It does not cancel admitted server work. There are no automatic retries.

The profile callback receives each event and must return `true` only when it is valid for the selected profile. It runs before send and after receive, including each update in a replay page. A `false` result stops the operation. Callback exceptions propagate to the caller. Use a separate configured client if different profile validators are needed.

## API

Each client operation returns `{:ok, event}` or `{:error, %DASP.Error{}}`. Events use string keys. The package creates no atoms from wire fields.

| Function | Reply |
| --- | --- |
| `Client.open/2` | `session.opened` |
| `Client.submit/3` | Admission `receipt` |
| `Client.read_view/2` | Coherent `view` |
| `Client.read_updates/3` or `/4` | `updates` page; default limit 100 |
| `Client.read_outcome/3` | Pending or settled `outcome` |
| `Wire.decode/1` / `Wire.encode/1` | Validated event / JSON bytes |

`DASP.Wire` validates core shapes and limits. It does not authenticate the producer or check application semantics. Use the client for request/reply checks. The adapter must authenticate push events before recovery code applies them.

## Recover state

```elixir
{:ok, view} = DASP.Client.read_view(client, session)
{:ok, checkpoint} = DASP.Checkpoint.from_view(view, &MyApp.CounterProfile.valid_event?/1)
:ok = MyApp.Store.save_checkpoint(checkpoint)
{:ok, page} = DASP.Client.read_updates(client, session, checkpoint["cursor"])
{:ok, next} = DASP.Checkpoint.apply_updates(
  checkpoint, page["data"]["events"],
  &MyApp.CounterProfile.reduce/2,
  &MyApp.CounterProfile.valid_event?/1
)
:ok = MyApp.Store.save_checkpoint(next)
```

Save state, cursor, and evidence in one transaction before acknowledging delivery. On restart, load that checkpoint, open the same session, and recover unresolved commands. Continue reading until `page["data"]["next"] == page["data"]["head"]`. The adapter defines the safe transition to a live stream.

The reducer must be pure. A failed batch returns no new checkpoint. Duplicate evidence stays in the checkpoint and can grow with history. Missing evidence for an old update requires a trusted view or a stop.

Error codes include `:invalid_json`, `:invalid_event`, `:configuration`, `:transport`, `:timeout`, `:correlation`, `:remote_failure`, `:profile`, `:replay`, `:checkpoint`, `:gap`, `:changed_update`, and `:missing_evidence`. A remote failure keeps the server error in `detail`. Transport failures and timeouts leave admission unresolved.

## Run the recorded example

```sh
mix deps.get
mix run examples/recorded.exs
```

See [recorded.exs](examples/recorded.exs). It uses a local reply adapter, not a server or network binding. See the [shared client guide](../README.md) for test coverage and limits.
