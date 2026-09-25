defmodule Jido.Seigyo.SessionForked do
  @moduledoc "The lineage and initial revisions of a new forked Session."

  use Jido.Signal,
    type: "jido.client.v1.session.forked",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "root_session_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "parent_session_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "fork_event_cursor" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "relation" => Zoi.enum(~w(fork side_chat)),
          "workspace_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
          "config_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "context_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
        },
        unrecognized_keys: :error
      )
end
