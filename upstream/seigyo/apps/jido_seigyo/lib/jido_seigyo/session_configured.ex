defmodule Jido.Seigyo.SessionConfigured do
  @moduledoc "The effective or pending result of a Session configuration request."

  use Jido.Signal,
    type: "jido.client.v1.session.configured",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "sequence" =>
            Zoi.integer()
            |> Zoi.min(1)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "disposition" => Zoi.enum(~w(applied pending duplicate)),
          "previous_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "effective_from" => Zoi.enum(~w(current next_command)),
          "config" => Jido.Seigyo.SessionConfig.schema()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :session_configured, []})
end
