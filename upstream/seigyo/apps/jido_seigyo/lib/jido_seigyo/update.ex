defmodule Jido.Seigyo.Update do
  @moduledoc "The closed version 1 ordered Update Signal."

  @event_types ~w(command_accepted turn_started turn_steered turn_cancel_requested command_completed command_failed command_cancelled command_uncertain session_configured context_compacted)
  @terminal_event_types ~w(command_completed command_failed command_cancelled command_uncertain)

  @json_non_negative Zoi.integer()
                     |> Zoi.min(0)
                     |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
  @json_positive Zoi.integer()
                 |> Zoi.min(1)
                 |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})

  @common_fields %{
    "version" => Zoi.literal(1),
    "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
    "sequence" =>
      Zoi.integer()
      |> Zoi.min(1)
      |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
  }

  @remote_common_fields Map.merge(@common_fields, %{
                          "kind" => Zoi.literal("event"),
                          "command_id" =>
                            Zoi.string()
                            |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []})
                        })
  @result_id Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :result_id, []})
  @remote_variants [
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("command_accepted"),
        "payload" =>
          Zoi.object(
            %{
              "kind" => Zoi.literal("submit_text"),
              "state" => Zoi.enum(~w(active queued))
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("command_completed"),
        "payload" => Zoi.object(%{"result_id" => @result_id}, unrecognized_keys: :error)
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("turn_started"),
        "payload" => Zoi.object(%{}, unrecognized_keys: :error)
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("turn_steered"),
        "payload" =>
          Zoi.object(
            %{
              "mutation_id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []})
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("turn_cancel_requested"),
        "payload" =>
          Zoi.object(
            %{
              "mutation_id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []})
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("command_cancelled"),
        "payload" =>
          Zoi.object(
            %{
              "mutation_id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []})
                |> Zoi.nullable(),
              "result_id" => @result_id
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("command_failed"),
        "payload" =>
          Zoi.object(
            %{
              "reason" => Zoi.enum(~w(execution_failed dispatch_unavailable admission_rejected)),
              "result_id" => @result_id
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@remote_common_fields, %{
        "event_type" => Zoi.literal("command_uncertain"),
        "payload" =>
          Zoi.object(
            %{
              "reason" => Zoi.enum(~w(agent_state_unknown server_restarted)),
              "result_id" => @result_id
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@common_fields, %{
        "kind" => Zoi.literal("event"),
        "command_id" => Zoi.literal(nil),
        "event_type" => Zoi.literal("session_configured"),
        "payload" =>
          Zoi.object(
            %{
              "mutation_id" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :mutation_id, []}),
              "config_revision" =>
                Zoi.integer()
                |> Zoi.min(1)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
              "previous_revision" =>
                Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
              "effective_from" => Zoi.enum(~w(current next_command)),
              "disposition" => Zoi.enum(~w(applied pending))
            },
            unrecognized_keys: :error
          )
      }),
      unrecognized_keys: :error
    ),
    Zoi.object(
      Map.merge(@common_fields, %{
        "kind" => Zoi.literal("event"),
        "command_id" => Zoi.literal(nil),
        "event_type" => Zoi.literal("context_compacted"),
        "payload" =>
          Zoi.object(
            %{
              "config_revision" => @json_non_negative,
              "previous_context_revision" => @json_non_negative,
              "context_revision" => @json_positive,
              "source_from_sequence" => @json_positive,
              "source_to_sequence" => @json_positive,
              "preserved_turns" => @json_non_negative,
              "estimated_tokens_before" => @json_non_negative,
              "estimated_tokens_after" => @json_non_negative,
              "reason" => Zoi.enum(~w(threshold model_change client_request recovery))
            },
            unrecognized_keys: :error
          )
          |> Zoi.refine({Jido.Seigyo.Contract, :context_compacted_payload, []})
      }),
      unrecognized_keys: :error
    )
    |> Zoi.refine({Jido.Seigyo.Contract, :context_compacted_update, []})
  ]
  @remote_schema Zoi.discriminated_union("event_type", @remote_variants)

  use Jido.Signal,
    type: "jido.client.v1.update",
    default_source: "/jido/code/server",
    schema: @remote_schema

  @doc "Returns the closed Update data schema for a version 1 client."
  @spec remote_schema() :: Zoi.schema()
  def remote_schema, do: @remote_schema

  @doc false
  def remote_variants, do: @remote_variants

  @doc "Returns every closed coding v1 Update event type."
  @spec event_types() :: [String.t()]
  def event_types, do: @event_types

  @doc "Checks whether an Update event settles its Command."
  @spec terminal_event?(term()) :: boolean()
  def terminal_event?(event_type), do: event_type in @terminal_event_types
end
