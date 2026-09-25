defmodule Jido.Seigyo.AttachmentCommit do
  @moduledoc "A request to verify and commit an uploaded Attachment."

  use Jido.Signal,
    type: "jido.client.v1.attachment.commit",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "attachment_id" =>
            Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :attachment_id, []})
        },
        unrecognized_keys: :error
      )
end
