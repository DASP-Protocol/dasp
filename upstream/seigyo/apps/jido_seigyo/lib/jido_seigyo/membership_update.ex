defmodule Jido.Seigyo.MembershipUpdate do
  @moduledoc "An ordered Update that includes the negotiated Session membership events."

  @common %{
    "version" => Zoi.literal(1),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
    "kind" => Zoi.literal("event"),
    "sequence" =>
      Zoi.integer()
      |> Zoi.min(1)
      |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
    "command_id" => Zoi.literal(nil)
  }

  @member_payload Zoi.object(
                    %{
                      "mutation_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
                      "previous_revision" =>
                        Zoi.integer()
                        |> Zoi.min(0)
                        |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
                      "member" => Jido.Seigyo.SessionMember.schema()
                    },
                    unrecognized_keys: :error
                  )

  @membership_variants [
    Zoi.object(
      Map.merge(@common, %{
        "event_type" => Zoi.literal("member_added"),
        "payload" => @member_payload
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@common, %{
        "event_type" => Zoi.literal("member_role_changed"),
        "payload" => @member_payload
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@common, %{
        "event_type" => Zoi.literal("member_removed"),
        "payload" => @member_payload
      }),
      unrecognized_keys: :error
    )
  ]

  @schema Zoi.discriminated_union(
            "event_type",
            Jido.Seigyo.Update.remote_variants() ++ @membership_variants
          )

  use Jido.Signal,
    type: "jido.client.v1.update",
    default_source: "/jido/code/server",
    schema: @schema

  @spec remote_schema() :: Zoi.schema()
  def remote_schema, do: @schema

  @spec event_types() :: [String.t()]
  def event_types,
    do: Jido.Seigyo.Update.event_types() ++ ~w(member_added member_role_changed member_removed)
end
