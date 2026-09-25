defmodule Jido.Seigyo.AttachmentBegin do
  @moduledoc "A request to begin one bounded immutable Attachment upload."

  use Jido.Signal,
    type: "jido.client.v1.attachment.begin",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "attachment_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "name" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
          "media_type" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :media_type, []}),
          "size" =>
            Zoi.integer()
            |> Zoi.min(1)
            |> Zoi.refine({Jido.Seigyo.Contract, :attachment_size, []}),
          "sha256" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []}),
          "purpose" => Zoi.enum(~w(context image patch workspace_import))
        },
        unrecognized_keys: :error
      )
end
