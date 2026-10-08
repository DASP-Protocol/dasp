defmodule DASP.Discovery.Control do
  @moduledoc false

  alias DASP.Signal.Fields

  @contract "https://dasp-protocol.github.io/dasp/contracts/capability-discovery"
  @version "draft-01"
  @operations ~w(capabilities.list capabilities.get capabilities.resource.read capabilities.snapshot.release)
  @failures ~w(unsupported_contract invalid_request unavailable invalid_continuation stale_snapshot request_limit item_too_large view_too_large snapshot_capacity resource_unavailable contract_violation)
  @limit_failures ~w(request_limit item_too_large view_too_large snapshot_capacity)
  @no_limit_failures @failures -- ["unavailable" | @limit_failures]
  @limit_names ~w(page_items view_items detail_items control_bytes presentation_bytes resource_bytes closure_resources closure_bytes opaque_bytes live_snapshots snapshot_retention_ms)

  def contract, do: @contract
  def version, do: @version

  def schema do
    Zoi.union([
      list_start_request(),
      list_continuation_request(),
      list_reply(true),
      list_reply(false),
      get_request(),
      get_reply(),
      resource_read_request(),
      resource_read_reply(),
      snapshot_release_request(),
      snapshot_release_reply(),
      failure("unavailable"),
      failure(:limit_capable),
      failure(:no_limit)
    ])
  end

  def manifest_schema do
    closed_map(%{
      "input_root" => opaque(),
      "output_root" => opaque(),
      "resources" => Zoi.array(resource_descriptor()) |> Zoi.min(1) |> Zoi.max(1000),
      "vocabularies" => Zoi.array(vocabulary_descriptor()) |> Zoi.max(1000),
      "closed" => Zoi.literal(true)
    })
  end

  def resource_descriptor_schema, do: resource_descriptor()

  defp list_start_request do
    document("capabilities.list", "request", %{
      "start" => opaque(),
      "actor" => opaque(),
      "limits" => selected_limits(),
      "advertised_view" => advertised_view() |> Zoi.optional()
    })
  end

  defp list_continuation_request do
    document("capabilities.list", "request", %{"continuation" => opaque()})
  end

  defp list_reply(complete?) do
    fields = %{
      "actor" => opaque(),
      "profile" => actor_profile(),
      "snapshot" => opaque(),
      "resolved_view" => opaque(),
      "page" => opaque(),
      "summaries" => Zoi.array(capability_summary()) |> Zoi.max(1000),
      "complete" => Zoi.literal(complete?)
    }

    fields =
      if complete? do
        fields
      else
        fields
        |> Map.put("summaries", Zoi.array(capability_summary()) |> Zoi.min(1) |> Zoi.max(1000))
        |> Map.put("continuation", opaque())
      end

    document("capabilities.list", "reply", fields)
  end

  defp get_request do
    document("capabilities.get", "request", %{
      "snapshot" => opaque(),
      "capabilities" => Zoi.array(capability_identity()) |> Zoi.min(1) |> Zoi.max(1000)
    })
  end

  defp get_reply do
    document("capabilities.get", "reply", %{
      "profile" => actor_profile(),
      "snapshot" => opaque(),
      "resolved_view" => opaque(),
      "details" => Zoi.array(capability_detail()) |> Zoi.min(1) |> Zoi.max(1000)
    })
  end

  defp resource_read_request do
    document("capabilities.resource.read", "request", %{
      "snapshot" => opaque(),
      "resource" => opaque()
    })
  end

  defp resource_read_reply do
    document("capabilities.resource.read", "reply", %{
      "snapshot" => opaque(),
      "resource" => resource_descriptor()
    })
  end

  defp snapshot_release_request do
    document("capabilities.snapshot.release", "request", %{"snapshot" => opaque()})
  end

  defp snapshot_release_reply do
    document("capabilities.snapshot.release", "reply", %{
      "snapshot" => opaque(),
      "released" => Zoi.literal(true)
    })
  end

  defp failure("unavailable") do
    header(%{
      "operation" => Zoi.enum(@operations),
      "kind" => Zoi.literal("failure"),
      "code" => Zoi.literal("unavailable")
    })
  end

  defp failure(:limit_capable) do
    header(%{
      "operation" => Zoi.enum(@operations),
      "kind" => Zoi.literal("failure"),
      "code" => Zoi.enum(@limit_failures),
      "limit" => limit_detail() |> Zoi.optional()
    })
  end

  defp failure(:no_limit) do
    header(%{
      "operation" => Zoi.enum(@operations),
      "kind" => Zoi.literal("failure"),
      "code" => Zoi.enum(@no_limit_failures)
    })
  end

  defp document(operation, kind, fields) do
    header(
      Map.merge(fields, %{"operation" => Zoi.literal(operation), "kind" => Zoi.literal(kind)})
    )
  end

  defp header(fields) do
    closed_map(
      Map.merge(fields, %{
        "contract" => Zoi.literal(@contract),
        "version" => Zoi.literal(@version)
      })
    )
  end

  defp selected_limits do
    integer = positive_integer()

    closed_map(%{
      "page_items" => integer,
      "view_items" => integer,
      "detail_items" => integer,
      "control_bytes" => integer,
      "presentation_bytes" => integer,
      "resource_bytes" => integer,
      "closure_resources" => integer,
      "closure_bytes" => integer,
      "opaque_bytes" => integer,
      "live_snapshots" => integer,
      "snapshot_retention_ms" => integer
    })
  end

  defp advertised_view do
    closed_map(%{"type" => uri(), "value" => opaque()})
  end

  defp actor_profile do
    closed_map(%{
      "uri" => uri(),
      "version" => version_value(),
      "content_ref" => uri(),
      "core" => contract_descriptor()
    })
  end

  defp contract_descriptor do
    closed_map(%{"id" => uri(), "version" => version_value(), "content_ref" => uri()})
  end

  defp capability_identity do
    closed_map(%{
      "profile_uri" => uri(),
      "profile_version" => version_value(),
      "command" => command_name()
    })
  end

  defp capability_summary do
    closed_map(%{
      "capability" => capability_identity(),
      "profile_requirement" => Zoi.enum(~w(required optional)),
      "label" => presentation() |> Zoi.optional(),
      "description" => presentation() |> Zoi.optional()
    })
  end

  defp capability_detail do
    closed_map(%{
      "capability" => capability_identity(),
      "profile_requirement" => Zoi.enum(~w(required optional)),
      "label" => presentation() |> Zoi.optional(),
      "description" => presentation() |> Zoi.optional(),
      "schemas" => manifest_schema()
    })
  end

  defp resource_descriptor do
    closed_map(%{
      "resource" => opaque(),
      "media_type" => Zoi.literal("application/schema+json"),
      "dialect" => uri(),
      "schema_id" => uri() |> Zoi.optional(),
      "byte_length" => Zoi.integer() |> Zoi.gte(0) |> Zoi.lte(2_147_483_647),
      "digest" => digest() |> Zoi.optional()
    })
  end

  defp digest do
    closed_map(%{
      "algorithm" => Zoi.literal("sha-256"),
      "media_type" => Zoi.literal("application/schema+json"),
      "value" => Zoi.string() |> Zoi.regex(~r/\A[0-9a-f]{64}\z/)
    })
  end

  defp vocabulary_descriptor do
    closed_map(%{"uri" => uri(), "required" => Zoi.boolean()})
  end

  defp limit_detail do
    closed_map(%{
      "name" => Zoi.enum(@limit_names),
      "maximum" => positive_integer(),
      "actual" => Zoi.integer() |> Zoi.gte(0) |> Zoi.lte(2_147_483_647) |> Zoi.optional()
    })
  end

  defp opaque, do: Fields.nonempty_string() |> Zoi.max(4096)
  defp presentation, do: Zoi.string() |> Zoi.max(8192)
  defp version_value, do: Fields.nonempty_string() |> Zoi.max(256)
  defp command_name, do: Fields.name()
  defp uri, do: Fields.uri() |> Zoi.max(4096)

  defp positive_integer,
    do: Zoi.integer() |> Zoi.gte(1) |> Zoi.lte(2_147_483_647)

  defp closed_map(fields), do: Zoi.map(fields, unrecognized_keys: :error)
end
