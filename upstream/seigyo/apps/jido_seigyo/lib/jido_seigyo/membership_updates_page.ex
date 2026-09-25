defmodule Jido.Seigyo.MembershipUpdatesPage do
  @moduledoc "A bounded Update page for a connection that negotiated Session membership."

  @schema Zoi.object(
            %{
              "version" => Zoi.literal(1),
              "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
              "after_sequence" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
              "updates" => Zoi.list(Jido.Seigyo.MembershipUpdate.remote_schema()) |> Zoi.max(100),
              "next_cursor" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
                |> Zoi.nullable()
            },
            unrecognized_keys: :error
          )
          |> Zoi.refine({Jido.Seigyo.Contract, :updates_page, []})

  use Jido.Signal,
    type: "jido.client.v1.updates.page",
    default_source: "/jido/code/server",
    schema: @schema
end
