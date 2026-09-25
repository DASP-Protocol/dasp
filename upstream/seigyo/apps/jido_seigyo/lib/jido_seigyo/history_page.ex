defmodule Jido.Seigyo.HistoryPage do
  @moduledoc "A bounded page of ordered Session history."

  @schema Zoi.object(
            %{
              "version" => Zoi.literal(1),
              "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
              "entries" => Zoi.list(Jido.Seigyo.HistoryEntry.schema()) |> Zoi.max(100),
              "next_cursor" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
                |> Zoi.nullable()
            },
            unrecognized_keys: :error
          )
          |> Zoi.refine({Jido.Seigyo.Contract, :history_page, []})

  use Jido.Signal,
    type: "jido.client.v1.history.page",
    default_source: "/jido/code/server",
    schema: @schema
end
