defmodule Jido.Seigyo.Tool do
  @moduledoc "The bounded tool summary used in client activity Signals."

  @schema Zoi.object(
            %{
              "id" => Zoi.string() |> Zoi.max(128),
              "name" => Zoi.string() |> Zoi.max(128),
              "status" => Zoi.enum(~w(running ok error completed unknown)),
              "duration_ms" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
                |> Zoi.nullable(),
              "truncated" => Zoi.boolean(),
              "summary" => Zoi.string() |> Zoi.max(200) |> Zoi.nullable()
            },
            unrecognized_keys: :error
          )

  def schema, do: @schema
end
