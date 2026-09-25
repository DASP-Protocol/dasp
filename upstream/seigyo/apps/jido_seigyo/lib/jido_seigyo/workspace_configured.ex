defmodule Jido.Seigyo.WorkspaceConfigured do
  @moduledoc "The result of one Workspace configuration mutation."

  use Jido.Signal,
    type: "jido.client.v1.workspace.configured",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "disposition" => Zoi.enum(~w(created updated unchanged)),
          "workspace" => Jido.Seigyo.Workspace.schema()
        },
        unrecognized_keys: :error
      )
end
