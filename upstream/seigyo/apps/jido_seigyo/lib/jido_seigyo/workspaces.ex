defmodule Jido.Seigyo.Workspaces do
  @moduledoc "The configured Workspaces visible to one principal."

  use Jido.Signal,
    type: "jido.client.v1.workspaces",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "workspaces" => Zoi.list(Jido.Seigyo.Workspace.schema()) |> Zoi.max(256)
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :workspaces, []})
end
