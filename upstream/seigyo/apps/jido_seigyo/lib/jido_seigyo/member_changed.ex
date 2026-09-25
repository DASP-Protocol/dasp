defmodule Jido.Seigyo.MemberChanged do
  @moduledoc "The durable result of one Session member mutation."

  use Jido.Signal,
    type: "jido.client.v1.session.member.changed",
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
          "previous_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "revision" =>
            Zoi.integer()
            |> Zoi.min(1)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "disposition" => Zoi.enum(~w(applied duplicate)),
          "action" => Zoi.enum(~w(added role_changed removed)),
          "member" => Jido.Seigyo.SessionMember.schema()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :member_changed, []})
end
