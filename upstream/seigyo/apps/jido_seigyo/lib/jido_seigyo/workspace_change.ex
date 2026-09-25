defmodule Jido.Seigyo.WorkspaceChange do
  @moduledoc "One changed path in a client-visible Workspace change set."

  @schema Zoi.object(
            %{
              "path" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :workspace_path, []}),
              "status" => Zoi.enum(~w(added modified deleted renamed copied untracked conflicted))
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end
