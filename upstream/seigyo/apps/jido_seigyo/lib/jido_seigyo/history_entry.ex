defmodule Jido.Seigyo.HistoryEntry do
  @moduledoc "One bounded user or assistant message in Session history."

  @schema Zoi.object(
            %{
              "sequence" =>
                Zoi.integer()
                |> Zoi.min(1)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
              "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
              "role" => Zoi.enum(~w(user assistant)),
              "text" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :history_text, []}),
              "truncated" => Zoi.boolean()
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end
