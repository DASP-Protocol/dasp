defmodule Jido.Seigyo.SessionOpened do
  @moduledoc "The server Signal that confirms one Session and Workspace link."

  use Jido.Signal,
    type: "jido.client.v1.session.opened",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "workspace_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
          "protocol_version" => Zoi.literal(1),
          "protocol_profile" => Zoi.literal("coding")
        },
        unrecognized_keys: :error
      )
end
