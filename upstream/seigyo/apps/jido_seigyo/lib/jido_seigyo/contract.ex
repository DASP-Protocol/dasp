defmodule Jido.Seigyo.Contract do
  @moduledoc false

  alias Jido.Seigyo.{ID, Value}

  @progress_text_limit 16_384
  @history_text_limit 4_000
  @workspace_patch_limit 65_536
  @session_instructions_limit 16_384
  @result_text_limit 32_768
  @result_blocks_bytes_limit 262_144
  @attachment_chunk_limit 65_536
  @attachment_size_limit 104_857_600
  @max_json_integer 9_007_199_254_740_991
  @websocket_frame_bytes_limit 524_288
  @signal_json_bytes_limit 512_000
  @updates_page_json_bytes_limit 262_144
  @request_ref_bytes_limit 128
  @page_items_limit 100

  def progress_text_limit, do: @progress_text_limit
  def history_text_limit, do: @history_text_limit
  def workspace_patch_limit, do: @workspace_patch_limit
  def session_instructions_limit, do: @session_instructions_limit
  def result_text_limit, do: @result_text_limit
  def result_blocks_bytes_limit, do: @result_blocks_bytes_limit
  def attachment_chunk_limit, do: @attachment_chunk_limit
  def attachment_size_limit, do: @attachment_size_limit
  def max_json_integer, do: @max_json_integer
  def websocket_frame_bytes_limit, do: @websocket_frame_bytes_limit
  def signal_json_bytes_limit, do: @signal_json_bytes_limit
  def updates_page_json_bytes_limit, do: @updates_page_json_bytes_limit
  def request_ref_bytes_limit, do: @request_ref_bytes_limit
  def page_items_limit, do: @page_items_limit

  def command_id(value, _opts), do: id(value, :command)
  def session_id(value, _opts), do: id(value, :session)
  def workspace_id(value, _opts), do: id(value, :workspace)
  def target_id(value, _opts), do: id(value, :target)
  def sandbox_id(value, _opts), do: id(value, :sandbox)
  def mutation_id(value, _opts), do: id(value, :mutation)
  def attachment_id(value, _opts), do: id(value, :attachment)
  def result_id(value, _opts), do: id(value, :result)
  def artifact_id(value, _opts), do: id(value, :artifact)
  def actor_id(value, _opts), do: id(value, :actor)
  def actor_instance_id(value, _opts), do: id(value, :actor_instance)

  def display_name(value, _opts) do
    if byte_size(value) <= 80 and String.valid?(value) and String.trim(value) != "" and
         not String.match?(value, ~r/[\x00-\x1F\x7F]/),
       do: :ok,
       else: invalid("invalid_field")
  end

  def text(value, _opts) do
    cond do
      byte_size(value) > 8_192 -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      String.trim(value) == "" -> invalid("invalid_field")
      true -> :ok
    end
  end

  def model(value, _opts) do
    if byte_size(value) <= 256 and String.valid?(value) and String.trim(value) != "" and
         not String.match?(value, ~r/[\x00-\x1F\x7F]/),
       do: :ok,
       else: invalid("invalid_field")
  end

  def name(value, _opts) do
    if byte_size(value) <= 64 and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, value),
      do: :ok,
      else: invalid("invalid_field")
  end

  def json_integer(value, _opts) do
    if value <= @max_json_integer,
      do: :ok,
      else: invalid("too_large")
  end

  def signal_type(value, _opts) do
    if byte_size(value) <= 128 and
         Regex.match?(~r/\Ajido\.client\.v[1-9][0-9]*\.[a-z][a-z0-9]*(?:\.[a-z0-9]+)*\z/, value),
       do: :ok,
       else: invalid("invalid_field")
  end

  def portable(value, _opts) do
    case Value.check(value) do
      :ok -> :ok
      {:error, code} -> invalid(code)
    end
  end

  def view_content(value, _opts) do
    outcomes = value["recent_outcomes"]
    sequences = Enum.map(outcomes, & &1["sequence"])
    active_id = get_in(value, ["active_command", "command_id"])
    outcome_ids = Enum.map(outcomes, & &1["command_id"])
    last_result = value["last_result"]
    last_result_command_id = value["last_result_command_id"]

    cond do
      sequences != Enum.sort(sequences, :desc) -> invalid("invalid_field")
      length(sequences) != length(Enum.uniq(sequences)) -> invalid("invalid_field")
      not is_nil(active_id) and active_id in outcome_ids -> invalid("invalid_field")
      is_nil(last_result) != is_nil(last_result_command_id) -> invalid("invalid_field")
      true -> portable(value, [])
    end
  end

  def updates_page(value, _opts) do
    updates = value["updates"]
    after_sequence = value["after_sequence"]

    cond do
      Enum.any?(updates, &(&1["session_id"] != value["session_id"])) ->
        invalid("invalid_field", "updates")

      not contiguous?(Enum.map(updates, & &1["sequence"])) ->
        invalid("invalid_field", "updates")

      updates != [] and hd(updates)["sequence"] != after_sequence + 1 ->
        invalid("invalid_field", "updates")

      not cursor_coherent?(updates, value["next_cursor"]) ->
        invalid("invalid_field", "next_cursor")

      true ->
        :ok
    end
  end

  def history_page(value, _opts) do
    entries = value["entries"]

    cond do
      not contiguous?(Enum.map(entries, & &1["sequence"])) ->
        invalid("invalid_field", "entries")

      not cursor_coherent?(entries, value["next_cursor"]) ->
        invalid("invalid_field", "next_cursor")

      true ->
        :ok
    end
  end

  def progress_text(value, _opts) do
    cond do
      byte_size(value) > @progress_text_limit -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      true -> :ok
    end
  end

  def history_text(value, _opts) do
    bounded_text(value, @history_text_limit)
  end

  def workspace_patch(value, _opts) do
    bounded_text(value, @workspace_patch_limit)
  end

  def session_instructions(value, _opts) do
    bounded_text(value, @session_instructions_limit)
  end

  def result_text(value, _opts) do
    bounded_text(value, @result_text_limit)
  end

  def reference(value, _opts) do
    if byte_size(value) <= 256 and String.valid?(value) and value != "" and
         not String.match?(value, ~r/[\x00-\x1F\x7F]/),
       do: :ok,
       else: invalid("invalid_field")
  end

  def request_ref(value, _opts) do
    if byte_size(value) in 1..@request_ref_bytes_limit and String.valid?(value) and
         not String.match?(value, ~r/[\x00-\x1F\x7F]/),
       do: :ok,
       else: invalid("invalid_field")
  end

  def sha256(value, _opts) do
    if Regex.match?(~r/\A[0-9a-f]{64}\z/, value),
      do: :ok,
      else: invalid("invalid_field")
  end

  def media_type(value, _opts) do
    if byte_size(value) <= 128 and
         Regex.match?(~r/\A[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*\z/, value),
       do: :ok,
       else: invalid("invalid_field")
  end

  def base64_chunk(value, _opts) do
    case Base.decode64(value) do
      {:ok, ""} -> invalid("invalid_field")
      {:ok, decoded} when byte_size(decoded) <= @attachment_chunk_limit -> :ok
      {:ok, _decoded} -> invalid("too_large")
      :error -> invalid("invalid_field")
    end
  end

  def attachment_size(value, _opts) do
    if value <= @attachment_size_limit,
      do: :ok,
      else: invalid("too_large")
  end

  def config_patch(value, _opts) do
    if map_size(value) > 0,
      do: :ok,
      else: invalid("invalid_field")
  end

  def fork_request(value, _opts) do
    override? = value["config_policy"] == "override"
    patch? = not is_nil(value["config_patch"])

    if override? == patch? and value["source_session_id"] != value["session_id"],
      do: :ok,
      else: invalid("invalid_field")
  end

  def reasoning(value, _opts) do
    visibility = value["visibility"]
    summary = value["summary"]

    if (visibility == "hidden" and is_nil(summary)) or
         (visibility == "summary" and is_binary(summary)),
       do: :ok,
       else: invalid("invalid_field")
  end

  def session_configuration(value, _opts) do
    effective = value["effective"]
    pending = value["pending"]

    cond do
      effective["state"] != "effective" ->
        invalid("invalid_field", "effective")

      not is_nil(pending) and pending["state"] != "pending" ->
        invalid("invalid_field", "pending")

      not is_nil(pending) and pending["revision"] <= effective["revision"] ->
        invalid("invalid_field", "pending")

      true ->
        :ok
    end
  end

  def configuration_history_page(value, _opts) do
    configurations = value["configurations"]
    revisions = Enum.map(configurations, & &1["revision"])

    expected_first =
      case value["after_revision"] do
        nil -> value["oldest_revision"]
        revision -> revision + 1
      end

    cond do
      revisions != Enum.sort(revisions) ->
        invalid("invalid_field", "configurations")

      revisions != Enum.uniq(revisions) ->
        invalid("invalid_field", "configurations")

      revisions != [] and hd(revisions) != expected_first ->
        invalid("invalid_field", "after_revision")

      revisions != [] and revisions != Enum.to_list(hd(revisions)..List.last(revisions)) ->
        invalid("gap", "configurations")

      not is_nil(value["next_cursor"]) and
          (revisions == [] or value["next_cursor"] != List.last(revisions)) ->
        invalid("invalid_field", "next_cursor")

      true ->
        :ok
    end
  end

  def session_configured(value, _opts) do
    config = value["config"]
    state = config["state"]
    effective_from = value["effective_from"]

    cond do
      config["revision"] != value["previous_revision"] + 1 ->
        invalid("invalid_field", "config")

      state == "effective" and effective_from != "current" ->
        invalid("invalid_field", "effective_from")

      state == "pending" and effective_from != "next_command" ->
        invalid("invalid_field", "effective_from")

      value["disposition"] == "applied" and state != "effective" ->
        invalid("invalid_field", "disposition")

      value["disposition"] == "pending" and state != "pending" ->
        invalid("invalid_field", "disposition")

      true ->
        :ok
    end
  end

  def context_compacted(value, _opts) do
    cond do
      value["context_revision"] != value["previous_context_revision"] + 1 ->
        invalid("invalid_field", "context_revision")

      value["source_from_sequence"] > value["source_to_sequence"] ->
        invalid("invalid_field", "source_from_sequence")

      value["source_to_sequence"] >= value["sequence"] ->
        invalid("invalid_field", "source_to_sequence")

      value["estimated_tokens_after"] > value["estimated_tokens_before"] ->
        invalid("invalid_field", "estimated_tokens_after")

      true ->
        :ok
    end
  end

  def context_compacted_payload(value, _opts) do
    cond do
      value["context_revision"] != value["previous_context_revision"] + 1 ->
        invalid("invalid_field", "context_revision")

      value["source_from_sequence"] > value["source_to_sequence"] ->
        invalid("invalid_field", "source_from_sequence")

      value["estimated_tokens_after"] > value["estimated_tokens_before"] ->
        invalid("invalid_field", "estimated_tokens_after")

      true ->
        :ok
    end
  end

  def context_compacted_update(value, _opts) do
    if value["payload"]["source_to_sequence"] < value["sequence"],
      do: :ok,
      else: invalid("invalid_field", "source_to_sequence")
  end

  def result(value, _opts) do
    status = value["status"]
    error = value["error"]

    cond do
      result_blocks_bytes(value["blocks"] || []) > @result_blocks_bytes_limit ->
        invalid("too_large", "blocks")

      (status in ~w(completed cancelled) and is_nil(error)) or
          (status in ~w(failed uncertain) and not is_nil(error)) ->
        :ok

      true ->
        invalid("invalid_field")
    end
  end

  def result_usage(value, _opts) do
    tokens =
      Enum.map(
        ~w(input_tokens output_tokens reasoning_tokens cache_read_tokens cache_write_tokens),
        &value[&1]
      )

    known = Enum.count(tokens, &is_integer/1)

    case {value["measurement"], known} do
      {"unavailable", 0} -> :ok
      {measurement, 5} when measurement in ~w(reported estimated) -> :ok
      {"mixed", count} when count in 1..5 -> :ok
      _ -> invalid("invalid_field", "measurement")
    end
  end

  defp result_blocks_bytes(blocks) do
    Enum.reduce(blocks, 0, fn block, total ->
      total + 128 +
        Enum.reduce(block, 0, fn
          {_key, value}, bytes when is_binary(value) -> bytes + byte_size(value)
          {_key, _value}, bytes -> bytes
        end)
    end)
  end

  def attachment(value, _opts) do
    state = value["state"]
    error = value["error"]
    uploaded = value["uploaded_bytes"]
    size = value["size"]

    cond do
      uploaded > size -> invalid("invalid_field")
      state == "ready" and (uploaded != size or not is_nil(error)) -> invalid("invalid_field")
      state == "rejected" and is_nil(error) -> invalid("invalid_field")
      state == "uploading" and not is_nil(error) -> invalid("invalid_field")
      true -> :ok
    end
  end

  def workspace_path(value, _opts) do
    cond do
      byte_size(value) > 4_096 -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      value == "" -> invalid("invalid_field")
      String.match?(value, ~r/[\x00-\x1F\x7F]/) -> invalid("invalid_field")
      true -> :ok
    end
  end

  def file_path(value, _opts) do
    cond do
      byte_size(value) > 4_096 -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      Path.type(value) != :absolute -> invalid("invalid_field")
      String.match?(value, ~r/[\x00-\x1F\x7F]/) -> invalid("invalid_field")
      true -> :ok
    end
  end

  def runtime_path(value, _opts) do
    cond do
      byte_size(value) > 4_096 -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      not String.starts_with?(value, "/") -> invalid("invalid_field")
      value != Path.expand(value, "/") -> invalid("invalid_field")
      String.match?(value, ~r/[\x00-\x1F\x7F]/) -> invalid("invalid_field")
      true -> :ok
    end
  end

  def workspace_name(value, _opts) do
    if byte_size(value) <= 256 and String.valid?(value) and String.trim(value) != "" and
         not String.match?(value, ~r/[\x00-\x1F\x7F]/),
       do: :ok,
       else: invalid("invalid_field")
  end

  def workspaces(value, _opts) do
    ids = Enum.map(value["workspaces"], & &1["id"])

    if length(ids) == length(Enum.uniq(ids)),
      do: :ok,
      else: invalid("invalid_field", "workspaces")
  end

  def session_members(value, _opts) do
    members = value["members"]
    ids = Enum.map(members, & &1["id"])
    actor_ids = Enum.map(members, & &1["actor_id"])

    cond do
      Enum.any?(members, &(&1["status"] != "active")) ->
        invalid("invalid_field", "members")

      length(ids) != length(Enum.uniq(ids)) ->
        invalid("invalid_field", "members")

      length(actor_ids) != length(Enum.uniq(actor_ids)) ->
        invalid("invalid_field", "members")

      true ->
        :ok
    end
  end

  def member_changed(value, _opts) do
    active_action? = value["action"] in ~w(added role_changed)
    expected_status = if active_action?, do: "active", else: "revoked"

    cond do
      value["revision"] != value["previous_revision"] + 1 ->
        invalid("invalid_field", "revision")

      value["member"]["revision"] != value["revision"] ->
        invalid("invalid_field", "member")

      value["member"]["status"] != expected_status ->
        invalid("invalid_field", "member")

      true ->
        :ok
    end
  end

  defp id(value, kind) do
    if ID.valid?(value, kind), do: :ok, else: invalid("invalid_id")
  end

  defp bounded_text(value, limit) do
    cond do
      byte_size(value) > limit -> invalid("too_large")
      not String.valid?(value) -> invalid("invalid_field")
      true -> :ok
    end
  end

  defp contiguous?([]), do: true

  defp contiguous?(sequences) do
    sequences
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [first, second] -> second == first + 1 end)
  end

  defp cursor_coherent?([], cursor), do: is_nil(cursor)
  defp cursor_coherent?(_items, nil), do: true
  defp cursor_coherent?(items, cursor), do: List.last(items)["sequence"] == cursor

  defp invalid(code) do
    {:error, Zoi.Error.custom_error(issue: {"invalid Jido Code value", [jido_code: code]})}
  end

  defp invalid(code, field) do
    {:error,
     Zoi.Error.custom_error(issue: {"invalid Jido Code value", [jido_code: code, field: field]})}
  end
end
