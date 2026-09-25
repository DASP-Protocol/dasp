defmodule Jido.Seigyo.CommandAttribution do
  @moduledoc "The durable member identity that submitted one Command."

  use Jido.Signal,
    type: "jido.client.v1.command.attribution",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "command_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
          "member_id" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :actor_instance_id, []}),
          "actor_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :actor_id, []}),
          "actor_kind" => Zoi.enum(~w(human actor)),
          "display_name" =>
            Zoi.string()
            |> Zoi.refine({Jido.Seigyo.Contract, :display_name, []})
        },
        unrecognized_keys: :error
      )
end
