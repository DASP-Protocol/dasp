defmodule DASP.Discovery.Enumeration do
  @moduledoc """
  Incremental validation state for capability summary pages.

  Summary callbacks run only after a complete page passes validation. Full
  summary accumulation is optional. Identity sets are always retained so that
  duplicate and detail checks remain exact.
  """

  alias DASP.Discovery
  import DASP.Error, only: [fail: 2]

  @enforce_keys [:accumulate, :on_page, :on_summary]
  defstruct actor: nil,
            profile: nil,
            snapshot: nil,
            resolved_view: nil,
            page_count: 0,
            item_count: 0,
            received_control_bytes: 0,
            complete: false,
            continuation: nil,
            capabilities: MapSet.new(),
            pages: MapSet.new(),
            continuations: MapSet.new(),
            last_command: nil,
            summaries: nil,
            limits: nil,
            max_pages: nil,
            max_items: nil,
            max_control_bytes: nil,
            accumulate: false,
            on_page: nil,
            on_summary: nil

  @type t :: %__MODULE__{}

  @doc "Creates empty page-validation state."
  @spec new(keyword()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def new(opts \\ []) do
    accumulate = Keyword.get(opts, :accumulate, false)
    on_page = Keyword.get(opts, :on_page)
    on_summary = Keyword.get(opts, :on_summary)
    limits = Keyword.get(opts, :limits)
    actor = Keyword.get(opts, :actor)
    max_pages = Keyword.get(opts, :max_pages)
    max_items = Keyword.get(opts, :max_items)
    max_control_bytes = Keyword.get(opts, :max_control_bytes)

    cond do
      not is_boolean(accumulate) ->
        error(:invalid_request, "The accumulate option must be boolean.")

      not is_nil(on_page) and not is_function(on_page, 1) ->
        error(:invalid_request, "The on_page option must be a one-argument function.")

      not is_nil(on_summary) and not is_function(on_summary, 1) ->
        error(:invalid_request, "The on_summary option must be a one-argument function.")

      not is_nil(limits) and not is_map(limits) ->
        error(:invalid_request, "Discovery limits must be a map.")

      not is_nil(actor) and not is_binary(actor) ->
        error(:invalid_request, "The expected discovery actor must be a string.")

      not valid_local_limit?(max_pages) ->
        error(:invalid_request, "The local page limit must be a positive integer.")

      not valid_local_limit?(max_items) ->
        error(:invalid_request, "The local item limit must be a positive integer.")

      not valid_local_limit?(max_control_bytes) ->
        error(:invalid_request, "The local control-byte limit must be a positive integer.")

      true ->
        {:ok,
         %__MODULE__{
           actor: actor,
           accumulate: accumulate,
           on_page: on_page,
           on_summary: on_summary,
           limits: limits,
           max_pages: max_pages,
           max_items: max_items,
           max_control_bytes: max_control_bytes,
           summaries: if(accumulate, do: [], else: nil)
         }}
    end
  end

  @doc "Validates and adds one list reply page."
  @spec push(t(), map() | binary()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def push(%__MODULE__{} = state, page) do
    DASP.Wire.protect(fn ->
      {page, control_bytes} = valid_page!(page)

      if state.complete,
        do: fail(:contract_violation, "A page followed the terminal discovery page.")

      validate_context!(state, page)
      validate_limits!(state, page, control_bytes)

      {capabilities, last_command} = validate_summaries!(state, page["summaries"])
      continuation = page["continuation"]

      if MapSet.member?(state.pages, page["page"]),
        do: fail(:contract_violation, "Discovery page identity repeated.")

      if continuation && MapSet.member?(state.continuations, continuation),
        do: fail(:contract_violation, "Discovery continuation loop detected.")

      run_callback!(state.on_page, page)
      Enum.each(page["summaries"], &run_callback!(state.on_summary, &1))

      next = %{
        state
        | actor: state.actor || page["actor"],
          profile: state.profile || page["profile"],
          snapshot: state.snapshot || page["snapshot"],
          resolved_view: state.resolved_view || page["resolved_view"],
          page_count: state.page_count + 1,
          item_count: state.item_count + length(page["summaries"]),
          received_control_bytes: state.received_control_bytes + control_bytes,
          complete: page["complete"],
          continuation: continuation,
          capabilities: capabilities,
          pages:
            if(page["complete"], do: MapSet.new(), else: MapSet.put(state.pages, page["page"])),
          continuations:
            cond do
              page["complete"] -> MapSet.new()
              continuation -> MapSet.put(state.continuations, continuation)
              true -> state.continuations
            end,
          last_command: last_command,
          summaries:
            if(state.accumulate,
              do: Enum.reverse(page["summaries"], state.summaries),
              else: nil
            )
      }

      next
    end)
  end

  @doc "Returns accumulated summaries in protocol order."
  @spec summaries(t()) :: {:ok, [map()]} | {:error, DASP.Error.t()}
  def summaries(%__MODULE__{accumulate: true, complete: true, summaries: summaries}),
    do: {:ok, Enum.reverse(summaries)}

  def summaries(%__MODULE__{accumulate: false}),
    do: error(:invalid_request, "Summary accumulation was not enabled.")

  def summaries(%__MODULE__{}),
    do: error(:contract_violation, "Capability enumeration is incomplete.")

  defp valid_page!(bytes) when is_binary(bytes) do
    case Discovery.decode(bytes) do
      {:ok, %{"operation" => "capabilities.list", "kind" => "reply"} = valid} ->
        {valid, byte_size(bytes)}

      {:ok, _} ->
        fail(:invalid_request, "Expected a capabilities.list reply.")

      {:error, error} ->
        raise error
    end
  end

  defp valid_page!(page) do
    case Discovery.validate(page) do
      {:ok, %{"operation" => "capabilities.list", "kind" => "reply"} = valid} -> valid
      {:ok, _} -> fail(:invalid_request, "Expected a capabilities.list reply.")
      {:error, error} -> raise error
    end
    |> then(&{&1, byte_size(DASP.JSON.encode!(&1))})
  end

  defp validate_context!(%__MODULE__{page_count: 0, actor: expected_actor}, page) do
    if is_binary(expected_actor) and page["actor"] != expected_actor,
      do: fail(:contract_violation, "Discovery reply actor differs from the requested actor.")

    Enum.each(page["summaries"], &ensure_profile!(&1["capability"], page["profile"]))
  end

  defp validate_context!(state, page) do
    if page["actor"] != state.actor or page["profile"] != state.profile or
         page["snapshot"] != state.snapshot or page["resolved_view"] != state.resolved_view,
       do: fail(:contract_violation, "Discovery page changed actor, profile, snapshot, or view.")

    Enum.each(page["summaries"], &ensure_profile!(&1["capability"], state.profile))
  end

  defp validate_summaries!(state, summaries) do
    Enum.reduce(summaries, {state.capabilities, state.last_command}, fn summary,
                                                                        {identities,
                                                                         previous_command} ->
      identity = summary["capability"]
      key = Discovery.capability_key(identity)
      command = identity["command"]

      if MapSet.member?(identities, key),
        do: fail(:contract_violation, "Duplicate capability identity in discovery pages.")

      if previous_command && not utf8_after?(command, previous_command),
        do: fail(:contract_violation, "Capability summaries are not in UTF-8 byte order.")

      {MapSet.put(identities, key), command}
    end)
  end

  defp validate_limits!(state, page, control_bytes) do
    limits = state.limits

    if is_map(limits) do
      if is_integer(limits["page_items"]) and length(page["summaries"]) > limits["page_items"],
        do: fail(:contract_violation, "Discovery page exceeds the selected item limit.")

      if is_integer(limits["view_items"]) and
           state.item_count + length(page["summaries"]) > limits["view_items"],
         do: fail(:contract_violation, "Discovery view exceeds the selected item limit.")

      if is_integer(limits["control_bytes"]) and control_bytes > limits["control_bytes"],
        do: fail(:contract_violation, "Discovery page exceeds the selected byte limit.")

      if is_integer(limits["presentation_bytes"]) do
        Enum.each(page["summaries"], fn summary ->
          Enum.each(~w(label description), fn field ->
            if is_binary(summary[field]) and
                 byte_size(summary[field]) > limits["presentation_bytes"],
               do:
                 fail(:contract_violation, "Discovery presentation value exceeds its byte limit.")
          end)
        end)
      end

      if is_integer(limits["opaque_bytes"]) do
        Enum.each(~w(actor snapshot resolved_view page continuation), fn field ->
          if is_binary(page[field]) and byte_size(page[field]) > limits["opaque_bytes"],
            do: fail(:contract_violation, "Discovery opaque value exceeds its byte limit.")
        end)
      end
    end

    if is_integer(state.max_pages) and state.page_count + 1 > state.max_pages,
      do: fail(:request_limit, "Discovery exceeds the local page limit.")

    if is_integer(state.max_items) and
         state.item_count + length(page["summaries"]) > state.max_items,
       do: fail(:request_limit, "Discovery exceeds the local item limit.")

    if is_integer(state.max_control_bytes) and
         state.received_control_bytes + control_bytes > state.max_control_bytes,
       do: fail(:request_limit, "Discovery exceeds the local control-byte limit.")
  end

  defp ensure_profile!(identity, profile) do
    if identity["profile_uri"] != profile["uri"] or
         identity["profile_version"] != profile["version"],
       do: fail(:contract_violation, "Capability identity differs from the snapshot profile.")
  end

  defp run_callback!(nil, _value), do: :ok

  defp run_callback!(callback, value) when is_function(callback, 1) do
    case callback.(value) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, %DASP.Error{} = error} -> raise error
      {:error, reason} -> fail(:callback, "Discovery callback failed: #{inspect(reason)}")
      other -> fail(:callback, "Discovery callback returned #{inspect(other)}.")
    end
  end

  defp utf8_after?(left, right), do: left > right

  defp valid_local_limit?(nil), do: true
  defp valid_local_limit?(value), do: is_integer(value) and value > 0

  defp error(code, message), do: {:error, %DASP.Error{code: code, message: message}}
end
