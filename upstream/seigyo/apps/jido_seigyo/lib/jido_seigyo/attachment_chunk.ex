defmodule Jido.Seigyo.AttachmentChunk do
  @moduledoc "One ordered bounded base64 chunk for an Attachment upload."

  use Jido.Signal,
    type: "jido.client.v1.attachment.chunk",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "attachment_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []}),
          "index" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "data" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :base64_chunk, []})
        },
        unrecognized_keys: :error
      )
end
