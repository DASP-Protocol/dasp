defmodule Jido.Seigyo.WorkspaceChanges do
  @moduledoc "The bounded current change set for one Session Workspace."

  use Jido.Signal,
    type: "jido.client.v1.workspace.changes",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "workspace_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
          "base_revision" => Zoi.string() |> Zoi.max(64) |> Zoi.nullable(),
          "clean" => Zoi.boolean(),
          "files" => Zoi.list(Jido.Seigyo.WorkspaceChange.schema()) |> Zoi.max(500),
          "patch" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :workspace_patch, []}),
          "truncated" => Zoi.boolean()
        },
        unrecognized_keys: :error
      )
end
