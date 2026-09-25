defmodule Jido.Seigyo.Workspace do
  @moduledoc "One configured Workspace exposed through the Seigyo Protocol."

  @schema Zoi.object(
            %{
              "id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
              "name" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :workspace_name, []}),
              "file_path" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :file_path, []}),
              "runtime_path" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :runtime_path, []}),
              "ownership" => Zoi.enum(~w(borrowed managed)),
              "mode" => Zoi.enum(~w(shared isolated)),
              "status" => Zoi.enum(~w(ready unavailable)),
              "version" =>
                Zoi.integer()
                |> Zoi.min(1)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end
