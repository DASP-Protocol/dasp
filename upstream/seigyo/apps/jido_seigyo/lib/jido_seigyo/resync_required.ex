defmodule Jido.Seigyo.ResyncRequired do
  @moduledoc "A live notice that requires a client to replay durable Updates."

  use Jido.Signal,
    type: "jido.client.v1.resync.required",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []})
        },
        unrecognized_keys: :error
      )
end
