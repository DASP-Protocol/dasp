defmodule Jido.Seigyo.SessionOpen do
  @moduledoc "The client Signal that opens one Session on a Workspace."

  use Jido.Signal,
    type: "jido.client.v1.session.open",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "workspace_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []})
            |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
end
