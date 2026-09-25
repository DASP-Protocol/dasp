defmodule Jido.Seigyo.TurnSubmit do
  @moduledoc "A queued coding turn request."

  @attachment_id Zoi.string()
                 |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []})

  use Jido.Signal,
    type: "jido.client.v1.turn.submit",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "text" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :text, []}),
          "attachment_ids" => Zoi.list(@attachment_id, unique_items: true) |> Zoi.max(32),
          "delivery" => Zoi.enum(~w(enqueue reject_if_busy)),
          "expected_config_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
end
