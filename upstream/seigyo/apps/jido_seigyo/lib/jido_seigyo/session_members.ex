defmodule Jido.Seigyo.SessionMembers do
  @moduledoc "The active durable members of one Session."

  use Jido.Signal,
    type: "jido.client.v1.session.members",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "members" => Zoi.list(Jido.Seigyo.SessionMember.schema()) |> Zoi.max(100)
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :session_members, []})
end
