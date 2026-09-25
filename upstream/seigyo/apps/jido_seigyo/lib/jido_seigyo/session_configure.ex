defmodule Jido.Seigyo.SessionConfigure do
  @moduledoc "A request to change future Session execution configuration."

  use Jido.Signal,
    type: "jido.client.v1.session.configure",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "expected_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "apply" => Zoi.enum(~w(when_idle next_command)),
          "patch" => Jido.Seigyo.SessionConfig.patch_schema()
        },
        unrecognized_keys: :error
      )
end
