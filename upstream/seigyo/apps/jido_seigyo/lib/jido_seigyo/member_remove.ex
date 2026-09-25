defmodule Jido.Seigyo.MemberRemove do
  @moduledoc "A retry-safe request to revoke one Session member grant."

  use Jido.Signal,
    type: "jido.client.v1.session.member.remove",
    default_source: "/jido/code/client",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "mutation_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "member_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :actor_instance_id, []}),
          "expected_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
        },
        unrecognized_keys: :error
      )
end
