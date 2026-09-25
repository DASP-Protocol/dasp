defmodule Jido.Seigyo.ContextCompacted do
  @moduledoc "A draft durable fact about one server-managed context compaction."

  @json_integer Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})

  use Jido.Signal,
    type: "jido.client.v1.context.compacted",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "sequence" => @json_integer |> Zoi.min(1),
          "config_revision" => @json_integer,
          "previous_context_revision" => @json_integer,
          "context_revision" => @json_integer,
          "source_from_sequence" => @json_integer,
          "source_to_sequence" => @json_integer,
          "preserved_turns" => @json_integer,
          "estimated_tokens_before" => @json_integer,
          "estimated_tokens_after" => @json_integer,
          "reason" => Zoi.enum(~w(threshold model_change client_request recovery))
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :context_compacted, []})
end
