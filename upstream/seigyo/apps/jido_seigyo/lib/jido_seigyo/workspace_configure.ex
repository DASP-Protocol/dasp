defmodule Jido.Seigyo.WorkspaceConfigure do
  @moduledoc "A retry-safe Workspace configuration request."

  use Jido.Signal,
    type: "jido.client.v1.workspace.configure",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "workspace_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
          "expected_version" =>
            Zoi.integer()
            |> Zoi.min(1)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            |> Zoi.nullable(),
          "name" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :workspace_name, []}),
          "file_path" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :file_path, []}),
          "runtime_path" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :runtime_path, []})
        },
        unrecognized_keys: :error
      )
end
