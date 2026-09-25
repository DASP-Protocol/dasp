defmodule Jido.Seigyo.SessionConfiguration do
  @moduledoc "The current effective and pending configuration of one Session."

  use Jido.Signal,
    type: "jido.client.v1.session.configuration",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "effective" => Jido.Seigyo.SessionConfig.schema(),
          "pending" => Jido.Seigyo.SessionConfig.schema() |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :session_configuration, []})
end
