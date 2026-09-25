defmodule Jido.Seigyo.Command do
  @moduledoc "The version 1 client command Signal."

  @common_fields %{
    "version" => Zoi.literal(1),
    "id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []})
  }
  @attachment_id Zoi.string()
                 |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []})
  @text_input Zoi.object(
                %{
                  "text" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :text, []}),
                  "attachment_ids" =>
                    Zoi.list(@attachment_id, unique_items: true) |> Zoi.max(32) |> Zoi.optional(),
                  "model" =>
                    Zoi.string()
                    |> Zoi.refine({Jido.Seigyo.Contract, :model, []})
                    |> Zoi.optional()
                },
                unrecognized_keys: :error
              )

  use Jido.Signal,
    type: "jido.client.v1.command",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        Map.merge(@common_fields, %{
          "kind" => Zoi.literal("submit_text"),
          "input" => @text_input
        }),
        unrecognized_keys: :error
      )
end
