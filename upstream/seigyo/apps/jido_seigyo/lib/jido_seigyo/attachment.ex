defmodule Jido.Seigyo.Attachment do
  @moduledoc "The safe client-visible state of one immutable Attachment."

  use Jido.Signal,
    type: "jido.client.v1.attachment",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "attachment_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "state" => Zoi.enum(~w(uploading ready rejected)),
          "name" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
          "media_type" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :media_type, []}),
          "size" =>
            Zoi.integer()
            |> Zoi.min(1)
            |> Zoi.refine({Jido.Seigyo.Contract, :attachment_size, []}),
          "sha256" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []}),
          "uploaded_bytes" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "next_chunk_index" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "error" => Jido.Seigyo.Error.schema() |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :attachment, []})
end
