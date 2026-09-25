defmodule Jido.Seigyo.SessionFork do
  @moduledoc "A request for a forked Session or side chat."

  use Jido.Signal,
    type: "jido.client.v1.session.fork",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "source_session_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "at_event_cursor" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "relation" => Zoi.enum(~w(fork side_chat)),
          "config_policy" => Zoi.enum(~w(inherit override)),
          "workspace_policy" => Zoi.enum(~w(snapshot shared_read_only shared_mutable)),
          "config_patch" => Jido.Seigyo.SessionConfig.patch_schema() |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :fork_request, []})
end
