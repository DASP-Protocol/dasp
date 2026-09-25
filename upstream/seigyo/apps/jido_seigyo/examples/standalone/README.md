# External Elixir consumer

Copy `mix.exs` and `client.exs` to a new directory outside the umbrella.
Use Elixir 1.20 or later and the local Jido Signal V3 checkout. Set these
variables to absolute checkout paths:

```sh
export SEIGYO_PACKAGE_PATH=/absolute/path/to/jido_code/apps/jido_seigyo
export SEIGYO_SIGNAL_PATH=/absolute/path/to/jido_signal
mix deps.get
mix compile
```

The consumer owns its `_build`, `deps`, and `mix.lock`. Keep them separate from
the server umbrella. The explicit Signal override replaces the development
sibling path in the Seigyo package. Do not use a Signal V2 dependency with V3.
For a reproducible checkout build, record both Git revisions and keep the
consumer lockfile. The Seigyo package has no Server, Jido AI, or Phoenix runtime
dependency; the WebSocket client uses WebSockex.

Provide a test endpoint and its authorized token in the environment:

```sh
export SEIGYO_URL=http://localhost:4000
# Set SEIGYO_TOKEN from your credential source; do not commit it.
mix run client.exs
```

This creates a Session and submits one brief model request. The script checks
that server modules are absent, initializes, reconnects, retries one Command,
reads Updates and Result, and prints `SEIGYO_STANDALONE_OK`. It uses no MockLLM
or server setup code. A separate acceptance fixture supplies the endpoint.
