defmodule Jido.Seigyo.SessionMember do
  @moduledoc "A durable human or Jido Actor access grant for one Session."

  @schema Zoi.object(
            %{
              "id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :actor_instance_id, []}),
              "actor_id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :actor_id, []}),
              "actor_kind" => Zoi.enum(~w(human actor)),
              "display_name" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :display_name, []}),
              "role" => Zoi.enum(~w(owner editor viewer)),
              "status" => Zoi.enum(~w(active revoked)),
              "revision" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end
