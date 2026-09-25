defmodule Jido.Seigyo.Catalog do
  @moduledoc """
  The public coding v1 operation, control, and event definitions.

  Catalog entries describe message data. Live decisions and runtime routes
  belong to the server. Signal order preserves the original v1 capability
  arrays; it has no execution or authorization meaning.
  """

  alias Jido.Seigyo.{Contract, Error, ID}

  @membership_feature "seigyo.membership/1"

  @operations [
    {"open", {Jido.Seigyo.SessionOpen, 1}, {Jido.Seigyo.SessionOpened, 1}, nil, :session,
     ~w(SEIGYO-TEST-001 SEIGYO-TEST-018)},
    {"submit", {Jido.Seigyo.Command, 2}, {Jido.Seigyo.Receipt, 2}, nil, :command,
     ~w(SEIGYO-TEST-002 SEIGYO-TEST-018)},
    {"updates", nil, {Jido.Seigyo.UpdatesPage, 3}, ~w(session_id after_sequence limit), :read,
     ~w(SEIGYO-TEST-007 SEIGYO-TEST-020)},
    {"history", nil, {Jido.Seigyo.HistoryPage, 4}, ~w(session_id after_sequence limit), :read,
     ~w(SEIGYO-TEST-007)},
    {"view", nil, {Jido.Seigyo.View, 5}, ~w(session_id), :read, ~w(SEIGYO-TEST-009)},
    {"trace", nil, {Jido.Seigyo.Trace, 6}, ~w(session_id command_id), :read, ~w(SEIGYO-TEST-004)},
    {"workspace_changes", nil, {Jido.Seigyo.WorkspaceChanges, 7}, ~w(session_id), :read,
     ~w(SEIGYO-TEST-004 CODING-SESSION-002)},
    {"workspaces", nil, {Jido.Seigyo.Workspaces, 17}, ~w(), :read, ~w(CODING-SESSION-016)},
    {"workspace_configure", {Jido.Seigyo.WorkspaceConfigure, 8},
     {Jido.Seigyo.WorkspaceConfigured, 18}, nil, :mutation,
     ~w(SEIGYO-TEST-019 CODING-SESSION-016)},
    {"execution_catalog", nil, {Jido.Seigyo.ExecutionCatalog, 8}, ~w(), :read,
     ~w(CODING-SESSION-012 CODING-SESSION-018)},
    {"configuration", nil, {Jido.Seigyo.SessionConfiguration, 9}, ~w(session_id), :read,
     ~w(CODING-SESSION-007)},
    {"configuration_history", nil, {Jido.Seigyo.SessionConfigurationsPage, 10},
     ~w(session_id after_revision limit), :read, ~w(CODING-SESSION-007)},
    {"configure", {Jido.Seigyo.SessionConfigure, 3}, {Jido.Seigyo.SessionConfigured, 11}, nil,
     :mutation, ~w(SEIGYO-TEST-019 CODING-SESSION-007)},
    {"fork", {Jido.Seigyo.SessionFork, 4}, {Jido.Seigyo.SessionForked, 12}, nil, :mutation,
     ~w(SEIGYO-TEST-019 CODING-SESSION-010 CODING-SESSION-017)},
    {"submit_turn", {Jido.Seigyo.TurnSubmit, 5}, {Jido.Seigyo.TurnReceipt, 13}, nil, :command,
     ~w(SEIGYO-TEST-002 CODING-SESSION-008)},
    {"steer_turn", {Jido.Seigyo.TurnSteer, 6}, {Jido.Seigyo.TurnControlled, 14}, nil, :mutation,
     ~w(SEIGYO-TEST-019 CODING-SESSION-008)},
    {"cancel_turn", {Jido.Seigyo.TurnCancel, 7}, {Jido.Seigyo.TurnControlled, 14}, nil, :mutation,
     ~w(SEIGYO-TEST-019 CODING-SESSION-008)},
    {"result", nil, {Jido.Seigyo.Result, 15}, ~w(session_id command_id), :read,
     ~w(SEIGYO-TEST-020 CODING-SESSION-013)},
    {"attachment_begin", {Jido.Seigyo.AttachmentBegin, 9}, {Jido.Seigyo.Attachment, 19}, nil,
     :mutation, ~w(SEIGYO-TEST-019 CODING-SESSION-011)},
    {"attachment_chunk", {Jido.Seigyo.AttachmentChunk, 10}, {Jido.Seigyo.Attachment, 19}, nil,
     :mutation, ~w(SEIGYO-TEST-019 CODING-SESSION-011)},
    {"attachment_commit", {Jido.Seigyo.AttachmentCommit, 11}, {Jido.Seigyo.Attachment, 19}, nil,
     :mutation, ~w(SEIGYO-TEST-019 CODING-SESSION-011)}
  ]

  @membership_operations [
    {"members", nil, {Jido.Seigyo.SessionMembers, 20}, ~w(session_id), :read,
     ~w(SEIGYO-TEST-011)},
    {"member_add", {Jido.Seigyo.MemberAdd, 12}, {Jido.Seigyo.MemberChanged, 21}, nil, :mutation,
     ~w(SEIGYO-TEST-011)},
    {"member_role_change", {Jido.Seigyo.MemberRoleChange, 13}, {Jido.Seigyo.MemberChanged, 21},
     nil, :mutation, ~w(SEIGYO-TEST-011)},
    {"member_remove", {Jido.Seigyo.MemberRemove, 14}, {Jido.Seigyo.MemberChanged, 21}, nil,
     :mutation, ~w(SEIGYO-TEST-011)},
    {"command_attribution", nil, {Jido.Seigyo.CommandAttribution, 22}, ~w(session_id command_id),
     :read, ~w(SEIGYO-TEST-011)}
  ]
  @membership_operation_names Enum.map(@membership_operations, &elem(&1, 0))

  @events [
    %{name: "update", signal: Jido.Seigyo.Update, authority: :saved},
    %{name: "progress", signal: Jido.Seigyo.Progress, authority: :transient},
    %{name: "resync_required", signal: Jido.Seigyo.ResyncRequired, authority: :delivery}
  ]
  @draft_signals [{:push, Jido.Seigyo.ContextCompacted}]
  @controls [
    {"watch_progress", ~w(request_ref session_id), "session_id", [Jido.Seigyo.Progress],
     ~w(progress), ~w(SEIGYO-TEST-003)},
    {"watch_updates", ~w(request_ref session_id after_sequence), Jido.Seigyo.UpdatesPage.type(),
     [Jido.Seigyo.Update, Jido.Seigyo.ResyncRequired], ~w(update resync_required),
     ~w(SEIGYO-TEST-008 SEIGYO-TEST-020)}
  ]

  @spec operations() :: [map()]
  def operations, do: operations([])

  @spec operations([String.t()]) :: [map()]
  def operations(features) when is_list(features) do
    entries = operation_entries(features)

    Enum.map(entries, fn {name, request, {result, _order}, arguments, retry, cases} ->
      operation = %{
        name: name,
        request: if(request, do: elem(request, 0)),
        result: result,
        arguments: arguments,
        args_schema: if(arguments, do: args_schema(arguments)),
        role: :request,
        direction: :client_to_server,
        profile: "coding",
        retry: retry,
        failures: Error.codes(),
        failure_delivery:
          if(retry == :command, do: ~w(failure rejected_receipt), else: ~w(failure)),
        requirements: ~w(SEIGYO-DEFINITION-001 SEIGYO-WIRE-004),
        conformance_cases: cases
      }

      if name in @membership_operation_names,
        do: Map.put(operation, :feature, @membership_feature),
        else: operation
    end)
  end

  @spec operation(term(), [String.t()]) :: {:ok, map()} | :error
  def operation(name, features \\ []) do
    case Enum.find(operations(features), &(&1.name == name)) do
      nil -> :error
      operation -> {:ok, operation}
    end
  end

  @spec operation_names([String.t()]) :: [String.t()]
  def operation_names(features \\ []), do: Enum.map(operations(features), & &1.name)

  @spec events() :: [map()]
  def events, do: @events

  @doc "Returns the role and direction of an advertised Signal type."
  @spec message(term(), [String.t()]) :: {:ok, map()} | :error
  def message(type, features \\ []) do
    case Enum.find(signals(features), fn {_role, module} -> module.type() == type end) do
      {:request, module} ->
        {:ok, %{signal: module, role: :request, direction: :client_to_server}}

      {:result, module} ->
        {:ok, %{signal: module, role: :reply, direction: :server_to_client}}

      {:push, module} ->
        event = Enum.find(@events, &(&1.signal.type() == module.type()))
        {:ok, Map.merge(event, %{role: :event, direction: :server_to_client})}

      nil ->
        :error
    end
  end

  @spec controls() :: [map()]
  def controls do
    Enum.map(@controls, fn {name, arguments, reply, signals, events, cases} ->
      %{
        name: name,
        arguments: arguments,
        args_schema: args_schema(arguments),
        reply: reply,
        push_signals: signals,
        push_events: events,
        role: :request,
        direction: :client_to_server,
        retry: :connection,
        requirements: ~w(SEIGYO-DEFINITION-002 SEIGYO-CORE-003 SEIGYO-CORE-005),
        conformance_cases: cases
      }
    end)
  end

  @spec control_names() :: [String.t()]
  def control_names, do: Enum.map(@controls, &elem(&1, 0))

  @spec signals([String.t()]) :: [{:request | :result | :push, module()}]
  def signals(features \\ []) do
    operations = operation_entries(features)

    requests = Enum.map(operations, &elem(&1, 1)) |> Enum.reject(&is_nil/1)
    replies = [{Jido.Seigyo.Failure, 16} | Enum.map(operations, &elem(&1, 2))]

    ordered_signals(requests, :request) ++
      ordered_signals(replies, :result) ++
      Enum.map(event_entries(features), &{:push, &1.signal})
  end

  defp operation_entries(features) do
    if @membership_feature in features do
      Enum.map(@operations, fn
        {"updates", request, {_result, order}, arguments, retry, cases} ->
          {"updates", request, {Jido.Seigyo.MembershipUpdatesPage, order}, arguments, retry,
           cases}

        entry ->
          entry
      end) ++ @membership_operations
    else
      @operations
    end
  end

  defp event_entries(features) do
    if @membership_feature in features do
      Enum.map(@events, fn
        %{name: "update"} = event -> %{event | signal: Jido.Seigyo.MembershipUpdate}
        event -> event
      end)
    else
      @events
    end
  end

  defp ordered_signals(entries, role) do
    entries
    |> Enum.uniq()
    |> Enum.sort_by(&elem(&1, 1))
    |> Enum.map(fn {module, _} -> {role, module} end)
  end

  @spec draft_signals() :: [{:request | :result | :push, module()}]
  def draft_signals, do: @draft_signals

  @spec signal_types(:request | :result | :push, [String.t()]) :: [String.t()]
  def signal_types(role, features \\ []),
    do: for({^role, module} <- signals(features), do: module.type())

  @spec draft_signal_types(:request | :result | :push) :: [String.t()]
  def draft_signal_types(role), do: for({^role, module} <- @draft_signals, do: module.type())

  @spec signal_module(String.t(), keyword()) :: {:ok, module()} | :error
  def signal_module(type, opts \\ []) when is_binary(type) do
    features = Keyword.get(opts, :features, [])

    candidates =
      if Keyword.get(opts, :include_drafts, false),
        do: signals(features) ++ @draft_signals,
        else: signals(features)

    case Enum.find(candidates, fn {_role, module} -> module.type() == type end) do
      {_role, module} -> {:ok, module}
      nil -> :error
    end
  end

  defp args_schema(arguments) do
    %{
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "type" => "object",
      "additionalProperties" => false,
      "required" => Enum.sort(arguments),
      "properties" => Map.new(arguments, &{&1, argument_schema(&1)})
    }
  end

  defp argument_schema("session_id"),
    do: %{"type" => "string", "pattern" => ID.patterns()["session"]}

  defp argument_schema("command_id"),
    do: %{"type" => "string", "pattern" => ID.patterns()["command"]}

  defp argument_schema(field) when field in ~w(after_sequence after_revision),
    do: %{"type" => "integer", "minimum" => 0, "maximum" => Contract.max_json_integer()}

  defp argument_schema("limit"),
    do: %{"type" => "integer", "minimum" => 1, "maximum" => Contract.page_items_limit()}

  defp argument_schema("request_ref") do
    %{
      "type" => "string",
      "minLength" => 1,
      "x-seigyo-maxUtf8Bytes" => Contract.request_ref_bytes_limit(),
      "pattern" => "^[^\\u0000-\\u001f\\u007f]+$"
    }
  end
end
