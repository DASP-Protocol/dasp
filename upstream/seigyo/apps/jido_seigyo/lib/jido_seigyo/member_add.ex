defmodule Jido.Seigyo.MemberAdd do
  @moduledoc "A retry-safe request to grant one registered Actor Session access."

  use Jido.Signal,
    type: "jido.client.v1.session.member.add",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "actor_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :actor_id, []}),
          "role" => Zoi.enum(~w(owner editor viewer)),
          "expected_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
        },
        unrecognized_keys: :error
      )
end
