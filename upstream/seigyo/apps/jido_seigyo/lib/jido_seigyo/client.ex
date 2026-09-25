defmodule Jido.Seigyo.Client do
  @moduledoc """
  A standalone WebSocket client for the Seigyo Protocol.

  The public API creates client Signals and returns client-friendly values.
  Phoenix frames and Signal envelopes stay inside the client.
  """

  use GenServer

  alias Jido.Seigyo.Client.Attachment, as: ClientAttachment
  alias Jido.Seigyo.Client.Capabilities
  alias Jido.Seigyo.Client.Connection
  alias Jido.Seigyo.Client.Error, as: ClientError
  alias Jido.Seigyo.Client.ExecutionCatalog, as: ClientExecutionCatalog
  alias Jido.Seigyo.Client.HistoryPage, as: ClientHistoryPage
  alias Jido.Seigyo.Client.CommandAttribution, as: ClientCommandAttribution
  alias Jido.Seigyo.Client.MemberChanged, as: ClientMemberChanged
  alias Jido.Seigyo.Client.Progress, as: ClientProgress
  alias Jido.Seigyo.Client.ReceiverRegistry
  alias Jido.Seigyo.Client.Receipt, as: ClientReceipt
  alias Jido.Seigyo.Client.Result, as: ClientResult
  alias Jido.Seigyo.Client.ResyncRequired, as: ClientResyncRequired
  alias Jido.Seigyo.Client.Session, as: ClientSession
  alias Jido.Seigyo.Client.SessionMembers, as: ClientSessionMembers
  alias Jido.Seigyo.Client.SessionConfiguration, as: ClientSessionConfiguration
  alias Jido.Seigyo.Client.SessionConfigurationsPage, as: ClientSessionConfigurationsPage
  alias Jido.Seigyo.Client.SessionConfigured, as: ClientSessionConfigured
  alias Jido.Seigyo.Client.SessionForked, as: ClientSessionForked
  alias Jido.Seigyo.Client.Trace, as: ClientTrace
  alias Jido.Seigyo.Client.TurnControlled, as: ClientTurnControlled
  alias Jido.Seigyo.Client.TurnReceipt, as: ClientTurnReceipt
  alias Jido.Seigyo.Client.Update, as: ClientUpdate
  alias Jido.Seigyo.Client.UpdatesPage, as: ClientUpdatesPage
  alias Jido.Seigyo.Client.View, as: ClientView
  alias Jido.Seigyo.Client.WorkspaceChanges, as: ClientWorkspaceChanges
  alias Jido.Seigyo.Client.WorkspaceConfigured, as: ClientWorkspaceConfigured
  alias Jido.Seigyo.Client.Workspaces, as: ClientWorkspaces
  alias Jido.Seigyo.Client.Wire
  alias Jido.Seigyo
  alias Jido.Seigyo.AttachmentBegin
  alias Jido.Seigyo.AttachmentChunk
  alias Jido.Seigyo.AttachmentCommit
  alias Jido.Seigyo.Command
  alias Jido.Seigyo.Error, as: SeigyoError
  alias Jido.Seigyo.MemberAdd
  alias Jido.Seigyo.MemberRemove
  alias Jido.Seigyo.MemberRoleChange
  alias Jido.Seigyo.MembershipUpdate, as: MembershipUpdateSignal
  alias Jido.Seigyo.MembershipUpdatesPage, as: MembershipUpdatesPageSignal
  alias Jido.Seigyo.Progress, as: ProgressSignal
  alias Jido.Seigyo.ResyncRequired, as: ResyncRequiredSignal
  alias Jido.Seigyo.SessionOpen
  alias Jido.Seigyo.SessionConfigure
  alias Jido.Seigyo.SessionFork
  alias Jido.Seigyo.TurnCancel
  alias Jido.Seigyo.TurnSteer
  alias Jido.Seigyo.TurnSubmit
  alias Jido.Seigyo.Update, as: UpdateSignal
  alias Jido.Seigyo.UpdatesPage, as: UpdatesPageSignal
  alias Jido.Seigyo.WorkspaceConfigure

  @topic "client:v1"
  @default_timeout 5_000
  @default_max_pending_updates 256
  @fork_timeout 60_000
  @updates_page_type UpdatesPageSignal.type()
  @result_type Seigyo.Result.type()
  @membership_feature "seigyo.membership/1"
  @membership_features [@membership_feature]

  defstruct [
    :connection,
    :join_ref,
    :capabilities,
    :selection,
    counter: 2,
    pending: %{},
    receiver_registry: nil,
    watched_progress_sessions: MapSet.new(),
    progress_sequences: %{},
    update_sequences: %{},
    update_replays: %{},
    update_replay_pending: %{},
    update_delivery_modes: %{},
    update_inflight: %{},
    update_queues: %{},
    max_pending_updates: @default_max_pending_updates,
    max_pending_requests: 128,
    max_watched_sessions: 64,
    progress_disabled: false,
    resync_sessions: MapSet.new(),
    settled_commands: MapSet.new()
  ]

  @type client :: GenServer.server()
  @type option ::
          {:url, String.t()}
          | {:token, String.t()}
          | {:profile, String.t()}
          | {:initialization, map()}
          | {:connect_timeout, pos_integer()}
          | {:max_pending_updates, pos_integer()}
          | {:max_pending_requests, pos_integer()}
          | {:max_watched_sessions, pos_integer()}
          | {:name, GenServer.name()}

  @doc "Starts a connected client and completes the protocol join."
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @doc "Opens or retries one Session. A Session ID is generated when omitted."
  @spec open(client(), ClientSession.t() | keyword() | String.t()) ::
          {:ok, Jido.Seigyo.Client.Session.t()} | {:error, term()}
  def open(client, session_or_opts \\ [])

  def open(client, %ClientSession{id: session_id}), do: open(client, session_id)

  def open(client, session_id) when is_binary(session_id),
    do: open(client, session_id: session_id)

  def open(client, opts) when is_list(opts) do
    session_id = Keyword.get_lazy(opts, :session_id, fn -> Seigyo.ID.generate(:session) end)
    workspace_id = Keyword.get(opts, :workspace_id)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "session_id" => session_id,
      "workspace_id" => workspace_id
    }

    with {:ok, signal} <- new_signal(SessionOpen, data),
         {:ok, result} <-
           request_signal(client, "open", signal, timeout),
         {:ok, session} <- ClientSession.from_data(result.data) do
      {:ok, session}
    end
  end

  @doc "Submits one text command. A Command ID is generated when omitted."
  @spec submit_text(client(), ClientSession.t() | String.t(), String.t(), keyword()) ::
          {:ok, Jido.Seigyo.Client.Receipt.t()} | {:error, term()}
  def submit_text(client, session, text, opts \\ []) when is_list(opts) do
    command_id = Keyword.get_lazy(opts, :command_id, fn -> Seigyo.ID.generate(:command) end)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    input =
      %{"text" => text}
      |> maybe_put("attachment_ids", Keyword.get(opts, :attachment_ids))
      |> maybe_put("model", Keyword.get(opts, :model))

    data = %{
      "version" => 1,
      "id" => command_id,
      "session_id" => session_id(session),
      "kind" => "submit_text",
      "input" => input
    }

    with {:ok, signal} <- new_command_signal(data),
         {:ok, result} <-
           request_signal(client, "submit", signal, timeout),
         {:ok, receipt} <- ClientReceipt.from_data(result.data) do
      {:ok, receipt}
    end
  end

  @doc "Reads the effective and pending Session configuration."
  @spec configuration(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, ClientSessionConfiguration.t()} | {:error, term()}
  def configuration(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    body = %{"args" => %{"session_id" => session_id(session)}}

    with {:ok, result} <-
           request(client, "configuration", body, timeout),
         {:ok, configuration} <- ClientSessionConfiguration.from_data(result.data) do
      {:ok, configuration}
    end
  end

  @doc "Reads one bounded page of saved Session configuration revisions."
  @spec configuration_history(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, ClientSessionConfigurationsPage.t()} | {:error, term()}
  def configuration_history(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    after_revision = Keyword.get(opts, :after)

    args = %{
      "session_id" => session_id(session),
      "after_revision" => after_revision,
      "limit" => Keyword.get(opts, :limit, 50)
    }

    with {:ok, result} <-
           request(
             client,
             "configuration_history",
             %{"args" => args},
             timeout
           ),
         {:ok, page} <- ClientSessionConfigurationsPage.from_data(result.data),
         true <- page.after_revision == after_revision do
      {:ok, page}
    else
      false -> {:error, ClientError.new(:protocol, :cursor_mismatch)}
      error -> error
    end
  end

  @doc "Reads the safe execution target and Sandbox profile catalog."
  @spec execution_catalog(client(), keyword()) ::
          {:ok, ClientExecutionCatalog.t()} | {:error, term()}
  def execution_catalog(client, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, result} <-
           request(client, "execution_catalog", %{"args" => %{}}, timeout),
         {:ok, catalog} <- ClientExecutionCatalog.from_data(result.data) do
      {:ok, catalog}
    end
  end

  @doc "Lists the configured Workspaces visible to this client."
  @spec workspaces(client(), keyword()) :: {:ok, ClientWorkspaces.t()} | {:error, term()}
  def workspaces(client, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, result} <-
           request(client, "workspaces", %{"args" => %{}}, timeout),
         {:ok, workspaces} <- ClientWorkspaces.from_data(result.data) do
      {:ok, workspaces}
    end
  end

  @doc "Creates or updates one Workspace."
  @spec configure_workspace(client(), String.t(), keyword()) ::
          {:ok, ClientWorkspaceConfigured.t()} | {:error, term()}
  def configure_workspace(client, file_path, opts \\ [])
      when is_binary(file_path) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "mutation_id" =>
        Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
      "workspace_id" =>
        Keyword.get_lazy(opts, :workspace_id, fn -> Seigyo.ID.generate(:workspace) end),
      "expected_version" => Keyword.get(opts, :expected_version),
      "name" => Keyword.get(opts, :name, Path.basename(file_path)),
      "file_path" => file_path,
      "runtime_path" => Keyword.get(opts, :runtime_path, "/workspace")
    }

    with {:ok, signal} <- new_signal(WorkspaceConfigure, data),
         {:ok, result} <-
           request_signal(client, "workspace_configure", signal, timeout),
         {:ok, configured} <- ClientWorkspaceConfigured.from_data(result.data) do
      {:ok, configured}
    end
  end

  @doc "Applies or stages one versioned Session configuration mutation."
  @spec configure(client(), ClientSession.t() | String.t(), map(), keyword()) ::
          {:ok, ClientSessionConfigured.t()} | {:error, term()}
  def configure(client, session, patch, opts \\ []) when is_map(patch) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "mutation_id" =>
        Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
      "session_id" => session_id(session),
      "expected_revision" => Keyword.get(opts, :expected_revision),
      "apply" => enum_value(Keyword.get(opts, :apply, :when_idle)),
      "patch" => patch
    }

    with {:ok, signal} <- new_signal(SessionConfigure, data),
         {:ok, result} <-
           request_signal(client, "configure", signal, timeout),
         {:ok, configured} <- ClientSessionConfigured.from_data(result.data) do
      {:ok, configured}
    end
  end

  @doc "Forks one committed Session position into an independent Session or side chat."
  @spec fork(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, ClientSessionForked.t()} | {:error, term()}
  def fork(client, source, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @fork_timeout)
    relation = enum_value(Keyword.get(opts, :relation, :fork))

    workspace_policy =
      opts
      |> Keyword.get_lazy(:workspace_policy, fn ->
        if relation == "side_chat", do: :shared_read_only, else: :snapshot
      end)
      |> enum_value()

    data = %{
      "version" => 1,
      "mutation_id" =>
        Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
      "source_session_id" => session_id(source),
      "session_id" => Keyword.get_lazy(opts, :session_id, fn -> Seigyo.ID.generate(:session) end),
      "at_event_cursor" => Keyword.get(opts, :at_event_cursor),
      "relation" => relation,
      "config_policy" => enum_value(Keyword.get(opts, :config_policy, :inherit)),
      "workspace_policy" => workspace_policy,
      "config_patch" => Keyword.get(opts, :config_patch)
    }

    with {:ok, signal} <- new_signal(SessionFork, data),
         {:ok, result} <-
           request_signal(client, "fork", signal, timeout),
         {:ok, forked} <- ClientSessionForked.from_data(result.data) do
      {:ok, forked}
    end
  end

  @doc "Submits one coding turn through the queue-aware protocol."
  @spec submit_turn(client(), ClientSession.t() | String.t(), String.t(), keyword()) ::
          {:ok, ClientTurnReceipt.t()} | {:error, term()}
  def submit_turn(client, session, text, opts \\ []) when is_binary(text) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "command_id" => Keyword.get_lazy(opts, :command_id, fn -> Seigyo.ID.generate(:command) end),
      "session_id" => session_id(session),
      "text" => text,
      "attachment_ids" => Keyword.get(opts, :attachment_ids, []),
      "delivery" => enum_value(Keyword.get(opts, :delivery, :reject_if_busy)),
      "expected_config_revision" => Keyword.get(opts, :expected_config_revision)
    }

    with {:ok, signal} <- new_signal(TurnSubmit, data),
         {:ok, result} <-
           request_signal(client, "submit_turn", signal, timeout),
         {:ok, receipt} <- ClientTurnReceipt.from_data(result.data) do
      {:ok, receipt}
    end
  end

  @doc "Queues steering text for one active turn."
  @spec steer(
          client(),
          ClientSession.t() | String.t(),
          ClientReceipt.t() | ClientTurnReceipt.t() | String.t(),
          String.t(),
          keyword()
        ) :: {:ok, ClientTurnControlled.t()} | {:error, term()}
  def steer(client, session, turn, text, opts \\ [])
      when is_binary(text) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "mutation_id" =>
        Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
      "session_id" => session_id(session),
      "target_command_id" => command_id(turn),
      "text" => text,
      "attachment_ids" => Keyword.get(opts, :attachment_ids, [])
    }

    with {:ok, signal} <- new_signal(TurnSteer, data),
         {:ok, result} <-
           request_signal(client, "steer_turn", signal, timeout),
         {:ok, controlled} <- ClientTurnControlled.from_data(result.data) do
      {:ok, controlled}
    end
  end

  @doc "Cancels one active or queued turn."
  @spec cancel(
          client(),
          ClientSession.t() | String.t(),
          ClientReceipt.t() | ClientTurnReceipt.t() | String.t(),
          keyword()
        ) :: {:ok, ClientTurnControlled.t()} | {:error, term()}
  def cancel(client, session, turn, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "mutation_id" =>
        Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
      "session_id" => session_id(session),
      "target_command_id" => command_id(turn),
      "reason" => Keyword.get(opts, :reason)
    }

    with {:ok, signal} <- new_signal(TurnCancel, data),
         {:ok, result} <-
           request_signal(client, "cancel_turn", signal, timeout),
         {:ok, controlled} <- ClientTurnControlled.from_data(result.data) do
      {:ok, controlled}
    end
  end

  @doc "Reads one stable normalized terminal Result."
  @spec result(
          client(),
          ClientSession.t() | String.t(),
          ClientReceipt.t() | ClientTurnReceipt.t() | String.t(),
          keyword()
        ) :: {:ok, ClientResult.t()} | {:error, term()}
  def result(client, session, command, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      "args" => %{
        "session_id" => session_id(session),
        "command_id" => command_id(command)
      }
    }

    with {:ok, result} <- request(client, "result", body, timeout),
         {:ok, value} <- ClientResult.from_data(result.data) do
      {:ok, value}
    end
  end

  @doc "Begins or resumes one immutable Attachment upload."
  @spec begin_attachment(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, ClientAttachment.t()} | {:error, term()}
  def begin_attachment(client, session, opts) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "attachment_id" =>
        Keyword.get_lazy(opts, :attachment_id, fn -> Seigyo.ID.generate(:attachment) end),
      "session_id" => session_id(session),
      "name" => Keyword.get(opts, :name),
      "media_type" => Keyword.get(opts, :media_type),
      "size" => Keyword.get(opts, :size),
      "sha256" => Keyword.get(opts, :sha256),
      "purpose" => enum_value(Keyword.get(opts, :purpose, :context))
    }

    with {:ok, signal} <- new_signal(AttachmentBegin, data),
         {:ok, result} <-
           request_signal(client, "attachment_begin", signal, timeout),
         {:ok, attachment} <- ClientAttachment.from_data(result.data) do
      {:ok, attachment}
    end
  end

  @doc "Uploads one ordered binary Attachment chunk."
  @spec upload_attachment_chunk(
          client(),
          ClientAttachment.t() | String.t(),
          non_neg_integer(),
          binary(),
          keyword()
        ) :: {:ok, ClientAttachment.t()} | {:error, term()}
  def upload_attachment_chunk(client, attachment, index, content, opts \\ [])
      when is_integer(index) and is_binary(content) and is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "attachment_id" => attachment_id(attachment),
      "index" => index,
      "data" => Base.encode64(content)
    }

    with {:ok, signal} <- new_signal(AttachmentChunk, data),
         {:ok, result} <-
           request_signal(client, "attachment_chunk", signal, timeout),
         {:ok, attachment} <- ClientAttachment.from_data(result.data) do
      {:ok, attachment}
    end
  end

  @doc "Verifies and commits one complete Attachment upload."
  @spec commit_attachment(client(), ClientAttachment.t() | String.t(), keyword()) ::
          {:ok, ClientAttachment.t()} | {:error, term()}
  def commit_attachment(client, attachment, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data = %{
      "version" => 1,
      "attachment_id" => attachment_id(attachment)
    }

    with {:ok, signal} <- new_signal(AttachmentCommit, data),
         {:ok, result} <-
           request_signal(client, "attachment_commit", signal, timeout),
         {:ok, attachment} <- ClientAttachment.from_data(result.data) do
      {:ok, attachment}
    end
  end

  @doc "Reads one bounded page of ordered Session updates."
  @spec updates(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, Jido.Seigyo.Client.UpdatesPage.t()} | {:error, term()}
  def updates(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    after_sequence = Keyword.get(opts, :after, 0)

    args = %{
      "session_id" => session_id(session),
      "after_sequence" => after_sequence,
      "limit" => Keyword.get(opts, :limit, 50)
    }

    with {:ok, result} <-
           request(client, "updates", %{"args" => args}, timeout),
         {:ok, page} <- ClientUpdatesPage.from_data(result.data),
         true <- page.after_sequence == after_sequence and page.session_id == session_id(session) do
      {:ok, page}
    else
      false -> {:error, ClientError.new(:protocol, :cursor_mismatch)}
      error -> error
    end
  end

  @doc "Reads the active human and Jido Actor members of one Session."
  def members(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    body = %{"args" => %{"session_id" => session_id(session)}}

    with {:ok, result} <- request(client, "members", body, timeout),
         {:ok, members} <- ClientSessionMembers.from_data(result.data) do
      {:ok, members}
    end
  end

  @doc "Grants a registered human or Jido Actor access to one Session."
  def add_member(client, session, actor_id, role, opts \\ []) when is_list(opts) do
    member_mutation(
      client,
      "member_add",
      MemberAdd,
      session,
      %{"actor_id" => actor_id, "role" => enum_value(role)},
      opts
    )
  end

  @doc "Changes one active Session member role."
  def change_member_role(client, session, member_id, role, opts \\ []) when is_list(opts) do
    member_mutation(
      client,
      "member_role_change",
      MemberRoleChange,
      session,
      %{"member_id" => member_id, "role" => enum_value(role)},
      opts
    )
  end

  @doc "Revokes one active Session member."
  def remove_member(client, session, member_id, opts \\ []) when is_list(opts) do
    member_mutation(
      client,
      "member_remove",
      MemberRemove,
      session,
      %{"member_id" => member_id},
      opts
    )
  end

  @doc "Reads the member identity that submitted one Command."
  def command_attribution(client, session, command, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      "args" => %{
        "session_id" => session_id(session),
        "command_id" => command_id(command)
      }
    }

    with {:ok, result} <- request(client, "command_attribution", body, timeout),
         {:ok, attribution} <- ClientCommandAttribution.from_data(result.data) do
      {:ok, attribution}
    end
  end

  defp member_mutation(client, operation, module, session, fields, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    data =
      fields
      |> Map.merge(%{
        "version" => 1,
        "mutation_id" =>
          Keyword.get_lazy(opts, :mutation_id, fn -> Seigyo.ID.generate(:mutation) end),
        "session_id" => session_id(session),
        "expected_revision" => Keyword.get(opts, :expected_revision)
      })

    with true <- is_integer(data["expected_revision"]) and data["expected_revision"] >= 0,
         {:ok, signal} <- new_signal(module, data),
         {:ok, result} <- request_signal(client, operation, signal, timeout),
         {:ok, changed} <- ClientMemberChanged.from_data(result.data) do
      {:ok, changed}
    else
      false -> {:error, SeigyoError.new("invalid_field", "expected_revision")}
      error -> error
    end
  end

  @doc "Reads one bounded page of ordered user and assistant history."
  @spec history(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, Jido.Seigyo.Client.HistoryPage.t()} | {:error, term()}
  def history(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    args = %{
      "session_id" => session_id(session),
      "after_sequence" => Keyword.get(opts, :after, 0),
      "limit" => Keyword.get(opts, :limit, 50)
    }

    with {:ok, result} <-
           request(client, "history", %{"args" => args}, timeout),
         {:ok, page} <- ClientHistoryPage.from_data(result.data) do
      {:ok, page}
    end
  end

  @doc "Reads the current bounded View for one Session."
  @spec view(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, Jido.Seigyo.Client.View.t()} | {:error, term()}
  def view(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    body = %{"args" => %{"session_id" => session_id(session)}}

    with {:ok, result} <- request(client, "view", body, timeout),
         {:ok, view} <- ClientView.from_data(result.data) do
      {:ok, view}
    end
  end

  @doc "Reads the bounded execution Trace for one command."
  @spec trace(
          client(),
          ClientSession.t() | String.t(),
          ClientReceipt.t() | String.t(),
          keyword()
        ) ::
          {:ok, Jido.Seigyo.Client.Trace.t()} | {:error, term()}
  def trace(client, session, command, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    body = %{
      "args" => %{
        "session_id" => session_id(session),
        "command_id" => command_id(command)
      }
    }

    with {:ok, result} <- request(client, "trace", body, timeout),
         {:ok, trace} <- ClientTrace.from_data(result.data) do
      {:ok, trace}
    end
  end

  @doc "Reads the current bounded change set for a Session Workspace."
  @spec workspace_changes(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, Jido.Seigyo.Client.WorkspaceChanges.t()} | {:error, term()}
  def workspace_changes(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    body = %{"args" => %{"session_id" => session_id(session)}}

    with {:ok, result} <-
           request(client, "workspace_changes", body, timeout),
         {:ok, changes} <- ClientWorkspaceChanges.from_data(result.data) do
      {:ok, changes}
    end
  end

  @doc "Attaches to committed Updates and returns the replay from one saved sequence."
  @spec watch_updates(client(), ClientSession.t() | String.t(), keyword()) ::
          {:ok, ClientUpdatesPage.t()} | {:error, term()}
  def watch_updates(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    receiver = Keyword.get(opts, :receiver, self())
    after_sequence = Keyword.get(opts, :after, 0)
    delivery = Keyword.get(opts, :delivery, :automatic)

    cond do
      not is_integer(timeout) or timeout <= 0 ->
        {:error, ClientError.new(:timeout, :invalid_timeout)}

      delivery not in [:automatic, :acknowledged] ->
        {:error, ClientError.new(:protocol, :invalid_watch_options)}

      true ->
        GenServer.call(
          client,
          {:watch_updates, session_id(session), after_sequence, receiver, delivery, timeout},
          timeout + 1_000
        )
    end
  end

  @doc "Acknowledges one applied replay or live Update, in order, with acknowledged delivery."
  @spec ack_update(client(), ClientUpdate.t()) :: :ok | {:error, term()}
  def ack_update(client, %ClientUpdate{} = update) do
    GenServer.call(client, {:ack_update, update})
  end

  @doc "Sends typed live Progress snapshots for one Session to the calling process."
  @spec watch_progress(client(), ClientSession.t() | String.t(), keyword()) ::
          :ok | {:error, term()}
  def watch_progress(client, session, opts \\ []) when is_list(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    receiver = Keyword.get(opts, :receiver, self())

    if is_integer(timeout) and timeout > 0 do
      GenServer.call(
        client,
        {:watch_progress, session_id(session), receiver, timeout},
        timeout + 1_000
      )
    else
      {:error, ClientError.new(:timeout, :invalid_timeout)}
    end
  end

  @doc "Returns the capability data from the control-topic join."
  @spec capabilities(client()) :: Capabilities.t()
  def capabilities(client), do: GenServer.call(client, :capabilities)

  @doc "Returns the selected contract for opt-in initialization, or nil for a legacy join."
  def selection(client), do: GenServer.call(client, :selection)

  @doc "Disconnects the WebSocket and stops the client."
  @spec disconnect(client()) :: :ok
  def disconnect(client), do: GenServer.call(client, :disconnect)

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    with {:ok, profile} <- fetch_optional_binary(opts, :profile, "coding"),
         {:ok, initialization} <- fetch_initialization(opts),
         {:ok, timeout} <- fetch_timeout(opts),
         {:ok, max_pending_updates} <- fetch_max_pending_updates(opts),
         {:ok, max_pending_requests} <- fetch_limit(opts, :max_pending_requests, 128, 1_024),
         {:ok, max_watched_sessions} <- fetch_limit(opts, :max_watched_sessions, 64, 100),
         {:ok, base_url} <- fetch_binary(opts, :url),
         {:ok, token} <- fetch_binary(opts, :token),
         {:ok, url} <- Connection.websocket_url(base_url, token),
         {:ok, connection} <- Connection.start_link(url, self()),
         :ok <- await_connected(connection, timeout),
         {:ok, capabilities, selection} <- join(connection, profile, initialization, timeout) do
      {:ok,
       %__MODULE__{
         connection: connection,
         join_ref: "1",
         capabilities: capabilities,
         selection: selection,
         receiver_registry: ReceiverRegistry.new(),
         max_pending_updates: max_pending_updates,
         max_pending_requests: max_pending_requests,
         max_watched_sessions: max_watched_sessions
       }}
    else
      {:error, %ClientError{} = error} -> {:stop, error}
      {:error, reason} -> {:stop, ClientError.new(:connection, reason)}
    end
  end

  @impl true
  def handle_call(:capabilities, _from, state), do: {:reply, state.capabilities, state}
  def handle_call(:selection, _from, state), do: {:reply, state.selection, state}

  def handle_call(:disconnect, _from, state) do
    Connection.close(state.connection)
    {:stop, :normal, :ok, state}
  end

  def handle_call(request, _from, state)
      when is_tuple(request) and elem(request, 0) in [:request, :watch_progress, :watch_updates] and
             map_size(state.pending) >= state.max_pending_requests do
    {:reply, {:error, SeigyoError.new("too_large", "requests")}, state}
  end

  def handle_call(
        {:request, op, body, request_signal_type, expected_module, timeout},
        from,
        state
      ) do
    capability =
      Capabilities.require_operation(
        state.capabilities,
        op,
        request_signal_type,
        expected_module.type()
      )

    cond do
      not is_integer(timeout) or timeout <= 0 ->
        {:reply, {:error, ClientError.new(:timeout, :invalid_timeout)}, state}

      capability != :ok ->
        {:reply, capability, state}

      true ->
        ref = Integer.to_string(state.counter)
        request_ref = "request-#{ref}"
        payload = body |> Map.put("op", op) |> Map.put("request_ref", request_ref)
        frame = [state.join_ref, ref, @topic, "call", payload]
        :ok = Connection.send_frame(state.connection, frame)
        timer = Process.send_after(self(), {:request_timeout, ref}, timeout)

        pending = %{
          from: from,
          kind: :signal,
          request_ref: request_ref,
          expected_module: expected_module,
          features: selected_features(state),
          response_identity: response_identity(op, body),
          timer: timer
        }

        next = %{
          state
          | counter: state.counter + 1,
            pending: Map.put(state.pending, ref, pending)
        }

        {:noreply, next}
    end
  end

  def handle_call({:watch_progress, session_id, receiver, timeout}, from, state) do
    capability =
      Capabilities.require_control(state.capabilities, "watch_progress", [ProgressSignal.type()])

    cond do
      not is_integer(timeout) or timeout <= 0 ->
        {:reply, {:error, ClientError.new(:timeout, :invalid_timeout)}, state}

      not is_pid(receiver) ->
        {:reply, {:error, ClientError.new(:protocol, :invalid_receiver)}, state}

      not Seigyo.ID.valid?(session_id, :session) ->
        {:reply, {:error, SeigyoError.new("invalid_id", "session_id")}, state}

      capability != :ok ->
        {:reply, capability, state}

      watch_limit?(state, session_id) ->
        {:reply, {:error, SeigyoError.new("too_large", "watched_sessions")}, state}

      true ->
        ref = Integer.to_string(state.counter)
        request_ref = "request-#{ref}"

        frame = [
          state.join_ref,
          ref,
          @topic,
          "watch_progress",
          %{"request_ref" => request_ref, "session_id" => session_id}
        ]

        :ok = Connection.send_frame(state.connection, frame)
        timer = Process.send_after(self(), {:request_timeout, ref}, timeout)

        pending = %{
          from: from,
          kind: {:watch_progress, session_id, receiver},
          request_ref: request_ref,
          timer: timer
        }

        next = %{
          state
          | counter: state.counter + 1,
            pending: Map.put(state.pending, ref, pending)
        }

        {:noreply, next}
    end
  end

  def handle_call(
        {:watch_updates, session_id, after_sequence, receiver, delivery, timeout},
        from,
        state
      ) do
    capability =
      Capabilities.require_control(state.capabilities, "watch_updates", [
        UpdateSignal.type(),
        ResyncRequiredSignal.type()
      ])

    cond do
      not is_integer(timeout) or timeout <= 0 ->
        {:reply, {:error, ClientError.new(:timeout, :invalid_timeout)}, state}

      not is_pid(receiver) ->
        {:reply, {:error, ClientError.new(:protocol, :invalid_receiver)}, state}

      not Seigyo.ID.valid?(session_id, :session) ->
        {:reply, {:error, SeigyoError.new("invalid_id", "session_id")}, state}

      not is_integer(after_sequence) or after_sequence < 0 ->
        {:reply, {:error, SeigyoError.new("invalid_field", "after_sequence")}, state}

      Seigyo.Contract.json_integer(after_sequence, []) != :ok ->
        {:reply, {:error, SeigyoError.new("invalid_field", "after_sequence")}, state}

      capability != :ok ->
        {:reply, capability, state}

      watch_limit?(state, session_id) ->
        {:reply, {:error, SeigyoError.new("too_large", "watched_sessions")}, state}

      Enum.any?(state.pending, fn
        {_ref, %{kind: {:watch_updates, ^session_id, _, _, _}}} -> true
        _ -> false
      end) ->
        {:reply, {:error, SeigyoError.new("conflict", "watch_updates")}, state}

      true ->
        ref = Integer.to_string(state.counter)
        request_ref = "request-#{ref}"

        frame = [
          state.join_ref,
          ref,
          @topic,
          "watch_updates",
          %{
            "request_ref" => request_ref,
            "session_id" => session_id,
            "after_sequence" => after_sequence
          }
        ]

        :ok = Connection.send_frame(state.connection, frame)
        timer = Process.send_after(self(), {:request_timeout, ref}, timeout)

        pending = %{
          from: from,
          kind: {:watch_updates, session_id, after_sequence, receiver, delivery},
          request_ref: request_ref,
          features: selected_features(state),
          timer: timer
        }

        next = %{
          state
          | counter: state.counter + 1,
            pending: Map.put(state.pending, ref, pending)
        }

        {:noreply, next}
    end
  end

  def handle_call({:ack_update, %ClientUpdate{session_id: session_id} = update}, _from, state) do
    pending = Map.get(state.update_replay_pending, session_id, [])

    cond do
      state.update_delivery_modes[session_id] != :acknowledged ->
        {:reply, {:error, ClientError.new(:protocol, :ack_not_enabled)}, state}

      MapSet.member?(state.resync_sessions, session_id) ->
        {:reply, {:error, ClientError.new(:protocol, :resync_required)}, state}

      pending != [] and hd(pending) == update ->
        state =
          state
          |> advance_update(update)
          |> Map.update!(:update_replay_pending, &Map.put(&1, session_id, tl(pending)))
          |> deliver_queued_update(session_id)

        {:reply, :ok, state}

      pending == [] and state.update_inflight[session_id] == update ->
        state =
          state
          |> advance_update(update)
          |> Map.update!(:update_inflight, &Map.delete(&1, session_id))
          |> deliver_queued_update(session_id)

        {:reply, :ok, state}

      true ->
        {:reply, {:error, ClientError.new(:protocol, :unexpected_ack)}, state}
    end
  end

  @impl true
  def handle_info({:jido_seigyo_frame, connection, frame}, %{connection: connection} = state) do
    handle_frame(frame, state)
  end

  def handle_info({:request_timeout, ref}, state) do
    case Map.pop(state.pending, ref) do
      {nil, _pending} ->
        {:noreply, state}

      {%{from: from} = request, pending} ->
        error = {:error, ClientError.new(:timeout, :request)}
        GenServer.reply(from, error)
        {:noreply, complete_request(%{state | pending: pending}, request, error)}
    end
  end

  def handle_info(
        {:jido_seigyo_invalid_frame, connection, reason},
        %{connection: connection} = state
      ) do
    stop_with_error(state, ClientError.new(:protocol, reason))
  end

  def handle_info(
        {:jido_seigyo_disconnected, connection, reason},
        %{connection: connection} = state
      ) do
    stop_with_error(state, ClientError.new(:connection, reason))
  end

  def handle_info(
        {:jido_seigyo_terminated, connection, reason},
        %{connection: connection} = state
      ) do
    stop_with_error(state, ClientError.new(:connection, reason))
  end

  def handle_info({:EXIT, connection, reason}, %{connection: connection} = state) do
    stop_with_error(state, ClientError.new(:connection, reason))
  end

  def handle_info({:DOWN, monitor, :process, receiver, _reason}, state) do
    case ReceiverRegistry.pop_monitor(state.receiver_registry, monitor, receiver) do
      {nil, _registry} ->
        {:noreply, state}

      {{:progress, _session_id, ^receiver}, registry} ->
        {:noreply, %{state | receiver_registry: registry}}

      {{:updates, session_id, ^receiver}, registry} ->
        {:noreply,
         %{
           state
           | receiver_registry: registry,
             update_delivery_modes: Map.delete(state.update_delivery_modes, session_id),
             update_replay_pending: Map.delete(state.update_replay_pending, session_id),
             update_inflight: Map.delete(state.update_inflight, session_id),
             update_queues: Map.delete(state.update_queues, session_id),
             resync_sessions: MapSet.put(state.resync_sessions, session_id)
         }}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{connection: connection}) when is_pid(connection) do
    if Process.alive?(connection), do: Connection.close(connection)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp request_signal(client, op, signal, timeout) do
    {:ok, %{request: request_module, result: result_module}} =
      Seigyo.Catalog.operation(op, @membership_features)

    with {:ok, map} <- Wire.encode_request(signal, request_module, @membership_features) do
      request(client, op, %{"signal" => map}, request_module.type(), result_module, timeout)
    end
  end

  defp request(client, op, body, timeout) do
    {:ok, %{result: expected_module}} = Seigyo.Catalog.operation(op, @membership_features)
    request(client, op, body, nil, expected_module, timeout)
  end

  defp request(client, op, body, request_signal_type, expected_module, timeout) do
    if is_integer(timeout) and timeout > 0 do
      GenServer.call(
        client,
        {:request, op, body, request_signal_type, expected_module, timeout},
        timeout + 1_000
      )
    else
      {:error, ClientError.new(:timeout, :invalid_timeout)}
    end
  end

  defp handle_frame(
         [join_ref, ref, @topic, "phx_reply", payload],
         %{join_ref: join_ref} = state
       ) do
    case Map.pop(state.pending, ref) do
      {nil, _pending} ->
        {:noreply, state}

      {request, pending} ->
        _ = Process.cancel_timer(request.timer)
        result = payload |> decode_reply(request) |> check_watch_overlap(state)
        GenServer.reply(request.from, result)
        {:noreply, complete_request(%{state | pending: pending}, request, result)}
    end
  end

  defp handle_frame(
         [join_ref, nil, @topic, "progress", payload],
         %{join_ref: join_ref} = state
       ) do
    with {:ok, signal} <- Wire.decode_result(payload, ProgressSignal),
         {:ok, progress} <- ClientProgress.from_data(signal.data),
         {:ok, state} <- deliver_progress(progress, state) do
      {:noreply, state}
    else
      {:error, %ClientError{} = error} -> stop_with_error(state, error)
      {:error, reason} -> stop_with_error(state, ClientError.new(:protocol, reason))
    end
  end

  defp handle_frame(
         [join_ref, nil, @topic, "update", payload],
         %{join_ref: join_ref} = state
       ) do
    features = selected_features(state)

    with {:ok, signal} <- Wire.decode_result(payload, update_signal_module(features), features),
         {:ok, update} <- ClientUpdate.from_data(signal.data),
         {:ok, state} <- deliver_update(update, state) do
      {:noreply, state}
    else
      {:error, %ClientError{} = error} -> stop_with_error(state, error)
      {:error, reason} -> stop_with_error(state, ClientError.new(:protocol, reason))
    end
  end

  defp handle_frame(
         [join_ref, nil, @topic, "resync_required", payload],
         %{join_ref: join_ref} = state
       ) do
    with {:ok, signal} <- Wire.decode_result(payload, ResyncRequiredSignal),
         {:ok, notice} <- ClientResyncRequired.from_data(signal.data),
         {:ok, state} <- deliver_resync_required(notice, state) do
      {:noreply, state}
    else
      {:error, %ClientError{} = error} -> stop_with_error(state, error)
      {:error, reason} -> stop_with_error(state, ClientError.new(:protocol, reason))
    end
  end

  defp handle_frame(_frame, state),
    do: stop_with_error(state, ClientError.new(:protocol, :unexpected_frame))

  defp decode_reply(
         %{
           "status" => "ok",
           "response" => %{"request_ref" => request_ref, "result" => result}
         } = payload,
         %{
           kind: :signal,
           request_ref: request_ref,
           expected_module: expected_module,
           response_identity: identity
         } = request
       ) do
    if exact_keys?(payload, ~w(response status)) and
         exact_keys?(payload["response"], ~w(request_ref result)),
       do:
         result
         |> Wire.decode_result(expected_module, Map.get(request, :features, []))
         |> check_response_identity(identity),
       else: {:error, ClientError.new(:protocol, :invalid_reply_shape)}
  end

  defp decode_reply(
         %{
           "status" => "ok",
           "response" => %{"request_ref" => request_ref, "result" => result}
         } = payload,
         %{
           kind: {:watch_updates, session_id, after_sequence, _receiver, _delivery},
           request_ref: request_ref
         } = request
       ) do
    if exact_keys?(payload, ~w(response status)) and
         exact_keys?(payload["response"], ~w(request_ref result)) do
      features = Map.get(request, :features, [])

      with {:ok, signal} <-
             Wire.decode_result(result, updates_page_signal_module(features), features),
           {:ok, page} <- ClientUpdatesPage.from_data(signal.data),
           true <- page.after_sequence == after_sequence and page.session_id == session_id do
        {:ok, page}
      else
        false -> {:error, ClientError.new(:protocol, :cursor_mismatch)}
        error -> error
      end
    else
      {:error, ClientError.new(:protocol, :invalid_reply_shape)}
    end
  end

  defp decode_reply(
         %{
           "status" => "ok",
           "response" => %{"request_ref" => request_ref, "session_id" => session_id}
         } = payload,
         %{
           kind: {:watch_progress, session_id, _receiver},
           request_ref: request_ref
         }
       ) do
    if exact_keys?(payload, ~w(response status)) and
         exact_keys?(payload["response"], ~w(request_ref session_id)),
       do: :ok,
       else: {:error, ClientError.new(:protocol, :invalid_reply_shape)}
  end

  defp decode_reply(
         %{
           "status" => "error",
           "response" => %{"request_ref" => request_ref, "failure" => failure}
         } = payload,
         %{request_ref: request_ref}
       ) do
    if exact_keys?(payload, ~w(response status)) and
         exact_keys?(payload["response"], ~w(failure request_ref)) do
      case Wire.decode_failure(failure) do
        {:ok, error} -> {:error, error}
        {:error, error} -> {:error, error}
      end
    else
      {:error, ClientError.new(:protocol, :invalid_reply_shape)}
    end
  end

  defp decode_reply(_payload, _request),
    do: {:error, ClientError.new(:protocol, :invalid_reply)}

  defp complete_request(
         state,
         %{kind: {:watch_progress, session_id, receiver}},
         :ok
       ) do
    %{
      state
      | receiver_registry:
          ReceiverRegistry.put(state.receiver_registry, :progress, session_id, receiver),
        watched_progress_sessions: MapSet.put(state.watched_progress_sessions, session_id)
    }
  end

  defp complete_request(
         state,
         %{kind: {:watch_updates, session_id, after_sequence, receiver, delivery}},
         {:ok, %ClientUpdatesPage{} = page}
       ) do
    {:ok, replay} = Seigyo.Replay.new(session_id, after: after_sequence)
    old = state.update_replays[session_id]

    fingerprints =
      if old,
        do: Map.filter(old.fingerprints, fn {seq, _} -> seq <= after_sequence end),
        else: %{}

    replay = %{replay | fingerprints: fingerprints}

    state =
      state
      |> put_update_receiver(session_id, receiver)
      |> Map.update!(:update_delivery_modes, &Map.put(&1, session_id, delivery))
      |> Map.update!(:update_sequences, &Map.put(&1, session_id, after_sequence))
      |> Map.update!(:update_replays, &Map.put(&1, session_id, replay))
      |> Map.update!(:update_inflight, &Map.delete(&1, session_id))
      |> Map.update!(:update_queues, &Map.delete(&1, session_id))
      |> Map.update!(:resync_sessions, &MapSet.delete(&1, session_id))
      |> Map.update!(:update_replay_pending, &Map.put(&1, session_id, []))

    state =
      if delivery == :acknowledged do
        %{
          state
          | update_replay_pending: Map.put(state.update_replay_pending, session_id, page.updates)
        }
      else
        Enum.reduce(page.updates, state, &advance_update(&2, &1))
      end

    if page.next_cursor do
      {:ok, notice} =
        ClientResyncRequired.from_data(%{"version" => 1, "session_id" => session_id})

      send(receiver, {:jido_code_resync_required, self(), notice})
      %{state | resync_sessions: MapSet.put(state.resync_sessions, session_id)}
    else
      state
    end
  end

  defp complete_request(state, %{kind: {:watch_updates, session_id, _, _, _}}, {:error, _}) do
    case ReceiverRegistry.get(state.receiver_registry, :updates, session_id) do
      receiver when is_pid(receiver) ->
        {:ok, state} = require_update_resync(state, receiver, session_id)
        state

      _ ->
        state
    end
  end

  defp complete_request(state, %{kind: :signal}, {:ok, %Jido.Signal{} = signal}) do
    settled = settled_commands(signal, state.settled_commands)
    bound_diagnostics(%{state | settled_commands: settled})
  end

  defp complete_request(state, _request, _result), do: state

  defp response_identity(op, body)
       when op in ~w(result updates view trace members command_attribution) do
    Map.take(body["args"], ~w(session_id command_id))
  end

  defp response_identity(_op, _body), do: %{}

  defp check_response_identity({:ok, signal} = result, identity) do
    if Enum.all?(identity, fn {key, value} -> signal.data[key] == value end),
      do: result,
      else: {:error, ClientError.new(:protocol, :identity_mismatch)}
  end

  defp check_response_identity(error, _identity), do: error

  defp check_watch_overlap({:ok, %ClientUpdatesPage{} = page} = result, state) do
    replay = state.update_replays[page.session_id]

    conflict? =
      replay &&
        Enum.any?(page.updates, fn update ->
          fingerprint = replay.fingerprints[update.sequence]
          fingerprint && fingerprint != Seigyo.Digest.sha256(ClientUpdate.to_data(update))
        end)

    if conflict?, do: {:error, ClientError.new(:protocol, :update_conflict)}, else: result
  end

  defp check_watch_overlap(result, _state), do: result

  defp settled_commands(
         %Jido.Signal{type: @updates_page_type, data: data},
         settled
       ) do
    data["updates"]
    |> Enum.filter(&Jido.Seigyo.Update.terminal_event?(&1["event_type"]))
    |> Enum.reduce(settled, fn update, acc ->
      MapSet.put(acc, {update["session_id"], update["command_id"]})
    end)
  end

  defp settled_commands(%Jido.Signal{type: @result_type, data: data}, settled),
    do: MapSet.put(settled, {data["session_id"], data["command_id"]})

  defp settled_commands(_signal, settled), do: settled

  defp selected_features(%{selection: %{"features" => features}}) when is_list(features),
    do: features

  defp selected_features(_state), do: []

  defp update_signal_module(features) do
    if @membership_feature in features, do: MembershipUpdateSignal, else: UpdateSignal
  end

  defp updates_page_signal_module(features) do
    if @membership_feature in features,
      do: MembershipUpdatesPageSignal,
      else: UpdatesPageSignal
  end

  defp deliver_progress(_progress, %{progress_disabled: true} = state), do: {:ok, state}

  defp deliver_progress(%ClientProgress{} = progress, state) do
    key = {progress.session_id, progress.command_id}
    previous = Map.get(state.progress_sequences, key, -1)

    cond do
      MapSet.member?(state.settled_commands, key) ->
        {:ok, state}

      progress.sequence <= previous ->
        {:ok, state}

      receiver = ReceiverRegistry.get(state.receiver_registry, :progress, progress.session_id) ->
        send(receiver, {:jido_code_progress, self(), progress})

        {:ok,
         bound_diagnostics(%{
           state
           | progress_sequences: Map.put(state.progress_sequences, key, progress.sequence)
         })}

      MapSet.member?(state.watched_progress_sessions, progress.session_id) ->
        {:ok, state}

      true ->
        {:error, :unexpected_progress}
    end
  end

  defp deliver_update(%ClientUpdate{} = update, state) do
    previous = Map.get(state.update_sequences, update.session_id, 0)
    receiver = ReceiverRegistry.get(state.receiver_registry, :updates, update.session_id)

    cond do
      MapSet.member?(state.resync_sessions, update.session_id) ->
        {:ok, state}

      update.sequence <= previous ->
        case Seigyo.Replay.check(
               state.update_replays[update.session_id],
               ClientUpdate.to_data(update)
             ) do
          {:ok, :duplicate} ->
            {:ok, state}

          {:error, %{code: "gap"}} when is_pid(receiver) ->
            require_update_resync(state, receiver, update.session_id)

          {:error, reason} ->
            {:error, reason}
        end

      not is_pid(receiver) ->
        {:error, :unexpected_update}

      update.sequence == previous + 1 and
          state.update_delivery_modes[update.session_id] == :automatic ->
        send(receiver, {:jido_code_update, self(), update})

        {:ok, advance_update(state, update)}

      state.update_delivery_modes[update.session_id] == :acknowledged ->
        queue_acknowledged_update(state, receiver, update, previous)

      true ->
        {:error, :update_gap}
    end
  end

  defp queue_acknowledged_update(state, receiver, update, previous) do
    session_id = update.session_id
    inflight = state.update_inflight[session_id]
    queue = Map.get(state.update_queues, session_id, :queue.new())
    replay_pending = Map.get(state.update_replay_pending, session_id, [])

    expected =
      case :queue.peek_r(queue) do
        {:value, %ClientUpdate{sequence: sequence}} ->
          sequence + 1

        :empty when is_struct(inflight, ClientUpdate) ->
          inflight.sequence + 1

        :empty ->
          if replay_pending == [], do: previous + 1, else: List.last(replay_pending).sequence + 1
      end

    cond do
      update.sequence < expected ->
        known =
          Enum.find(
            replay_pending ++ List.wrap(inflight) ++ :queue.to_list(queue),
            &(&1.sequence == update.sequence)
          )

        if known == update, do: {:ok, state}, else: {:error, :update_conflict}

      update.sequence > expected ->
        {:error, :update_gap}

      is_nil(inflight) and replay_pending == [] ->
        send(receiver, {:jido_code_update, self(), update})
        {:ok, %{state | update_inflight: Map.put(state.update_inflight, session_id, update)}}

      :queue.len(queue) >= state.max_pending_updates ->
        require_update_resync(state, receiver, session_id)

      true ->
        {:ok,
         %{
           state
           | update_queues: Map.put(state.update_queues, session_id, :queue.in(update, queue))
         }}
    end
  end

  defp require_update_resync(state, receiver, session_id) do
    {:ok, notice} =
      ClientResyncRequired.from_data(%{"version" => 1, "session_id" => session_id})

    send(receiver, {:jido_code_resync_required, self(), notice})

    {:ok,
     %{
       state
       | update_replay_pending: Map.delete(state.update_replay_pending, session_id),
         update_inflight: Map.delete(state.update_inflight, session_id),
         update_queues: Map.delete(state.update_queues, session_id),
         resync_sessions: MapSet.put(state.resync_sessions, session_id)
     }}
  end

  defp advance_update(state, %ClientUpdate{} = update) do
    {:ok, replay} =
      Seigyo.Replay.commit(state.update_replays[update.session_id], ClientUpdate.to_data(update))

    %{
      state
      | update_sequences: Map.put(state.update_sequences, update.session_id, update.sequence),
        update_replays: Map.put(state.update_replays, update.session_id, replay),
        settled_commands: settle_update(update, state.settled_commands)
    }
    |> bound_diagnostics()
  end

  defp deliver_queued_update(state, session_id) do
    if Map.get(state.update_replay_pending, session_id, []) != [] or
         state.update_inflight[session_id] != nil or
         MapSet.member?(state.resync_sessions, session_id) do
      state
    else
      pop_queued_update(state, session_id)
    end
  end

  defp pop_queued_update(state, session_id) do
    queue = Map.get(state.update_queues, session_id, :queue.new())

    case :queue.out(queue) do
      {{:value, update}, rest} ->
        case ReceiverRegistry.get(state.receiver_registry, :updates, session_id) do
          receiver when is_pid(receiver) ->
            send(receiver, {:jido_code_update, self(), update})

            %{
              state
              | update_inflight: Map.put(state.update_inflight, session_id, update),
                update_queues: put_or_delete_queue(state.update_queues, session_id, rest)
            }

          _receiver ->
            %{state | resync_sessions: MapSet.put(state.resync_sessions, session_id)}
        end

      {:empty, _queue} ->
        %{state | update_queues: Map.delete(state.update_queues, session_id)}
    end
  end

  defp put_or_delete_queue(queues, session_id, queue) do
    if :queue.is_empty(queue),
      do: Map.delete(queues, session_id),
      else: Map.put(queues, session_id, queue)
  end

  defp put_update_receiver(state, session_id, receiver) do
    %{
      state
      | receiver_registry:
          ReceiverRegistry.put(state.receiver_registry, :updates, session_id, receiver)
    }
  end

  defp deliver_resync_required(%ClientResyncRequired{} = notice, state) do
    case ReceiverRegistry.get(state.receiver_registry, :updates, notice.session_id) do
      receiver when is_pid(receiver) ->
        send(receiver, {:jido_code_resync_required, self(), notice})

        {:ok,
         %{
           state
           | resync_sessions: MapSet.put(state.resync_sessions, notice.session_id),
             update_inflight: Map.delete(state.update_inflight, notice.session_id),
             update_replay_pending: Map.delete(state.update_replay_pending, notice.session_id),
             update_queues: Map.delete(state.update_queues, notice.session_id)
         }}

      _receiver ->
        {:error, :unexpected_resync_required}
    end
  end

  defp settle_update(
         %ClientUpdate{event_type: event_type, session_id: session_id, command_id: command_id},
         settled
       ) do
    if Jido.Seigyo.Update.terminal_event?(event_type),
      do: MapSet.put(settled, {session_id, command_id}),
      else: settled
  end

  defp join(connection, profile, initialization, timeout) do
    ref = "1"
    offer = initialization || %{"version" => 1, "profile" => profile}
    frame = [ref, ref, @topic, "phx_join", offer]
    :ok = Connection.send_frame(connection, frame)
    deadline = System.monotonic_time(:millisecond) + timeout

    case await_join(connection, ref, deadline) do
      {:ok, response} ->
        with {:ok, capabilities, selection} <- decode_selection(initialization, response),
             :ok <- selected_profile(capabilities, profile) do
          {:ok, capabilities, selection}
        end

      error ->
        error
    end
  end

  defp fetch_initialization(opts) do
    case Keyword.get(opts, :initialization) do
      nil ->
        {:ok, nil}

      offer ->
        with :ok <- Jido.Seigyo.Initialization.validate_offer(offer), do: {:ok, offer}
    end
  end

  defp decode_selection(nil, response) do
    with {:ok, capabilities} <- Capabilities.from_data(response), do: {:ok, capabilities, nil}
  end

  defp decode_selection(offer, response) do
    with :ok <- Jido.Seigyo.Initialization.validate_selection(offer, response),
         :ok <-
           Jido.Seigyo.Initialization.readable(
             Jido.Seigyo.Initialization.legacy_requirements(),
             response
           ),
         {:ok, capabilities} <- Capabilities.from_data(response["capabilities"]) do
      {:ok, capabilities, response}
    end
  end

  defp await_connected(connection, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    receive do
      {:jido_seigyo_connected, ^connection} -> :ok
      {:jido_seigyo_disconnected, ^connection, reason} -> {:error, reason}
      {:jido_seigyo_terminated, ^connection, reason} -> {:error, reason}
      {:EXIT, ^connection, reason} -> {:error, reason}
    after
      remaining(deadline) -> {:error, :connect_timeout}
    end
  end

  defp await_join(connection, ref, deadline) do
    receive do
      {:jido_seigyo_frame, ^connection,
       [^ref, ^ref, @topic, "phx_reply", %{"status" => "ok", "response" => response}]} ->
        {:ok, response}

      {:jido_seigyo_frame, ^connection, [^ref, ^ref, @topic, "phx_reply", %{"status" => "error"}]} ->
        {:error, :join_rejected}

      {:jido_seigyo_invalid_frame, ^connection, reason} ->
        {:error, reason}

      {:jido_seigyo_disconnected, ^connection, reason} ->
        {:error, reason}

      {:jido_seigyo_terminated, ^connection, reason} ->
        {:error, reason}

      {:EXIT, ^connection, reason} ->
        {:error, reason}

      _other ->
        await_join(connection, ref, deadline)
    after
      remaining(deadline) -> {:error, :join_timeout}
    end
  end

  defp selected_profile(%Capabilities{profile: profile}, profile), do: :ok
  defp selected_profile(_capabilities, _profile), do: {:error, :profile_mismatch}

  defp stop_with_error(state, error) do
    Enum.each(state.pending, fn {_ref, request} ->
      _ = Process.cancel_timer(request.timer)
      GenServer.reply(request.from, {:error, error})
    end)

    {:stop, :normal, %{state | pending: %{}}}
  end

  defp new_signal(module, data) do
    case module.new(data) do
      {:ok, signal} -> {:ok, signal}
      {:error, errors} when is_list(errors) -> {:error, SeigyoError.from_zoi(errors)}
      {:error, reason} -> {:error, ClientError.new(:protocol, reason)}
    end
  end

  defp new_command_signal(data) do
    case Command.new(data) do
      {:ok, signal} -> {:ok, signal}
      {:error, errors} when is_list(errors) -> {:error, command_error(errors)}
      {:error, reason} -> {:error, ClientError.new(:protocol, reason)}
    end
  end

  defp command_error([%Zoi.Error{path: path} | _] = errors) do
    error = SeigyoError.from_zoi(errors)

    field =
      case path do
        ["id" | _rest] -> "command_id"
        ["input", input_field | _rest] when input_field in ~w(text model) -> input_field
        _path -> error.field
      end

    %{error | field: field}
  end

  defp command_error(errors), do: SeigyoError.from_zoi(errors)

  defp fetch_binary(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _error -> {:error, {:missing_option, key}}
    end
  end

  defp fetch_optional_binary(opts, key, default) do
    case Keyword.get(opts, key, default) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:invalid_option, key}}
    end
  end

  defp fetch_timeout(opts) do
    case Keyword.get(opts, :connect_timeout, @default_timeout) do
      timeout when is_integer(timeout) and timeout > 0 -> {:ok, timeout}
      _timeout -> {:error, {:invalid_option, :connect_timeout}}
    end
  end

  defp fetch_max_pending_updates(opts) do
    fetch_limit(opts, :max_pending_updates, @default_max_pending_updates, 1_000)
  end

  defp fetch_limit(opts, key, default, maximum) do
    case Keyword.get(opts, key, default) do
      limit when is_integer(limit) and limit > 0 and limit <= maximum -> {:ok, limit}
      _limit -> {:error, {:invalid_option, key}}
    end
  end

  defp watch_limit?(state, session_id) do
    sessions =
      MapSet.union(state.watched_progress_sessions, MapSet.new(Map.keys(state.update_sequences)))

    sessions =
      Enum.reduce(state.pending, sessions, fn
        {_, %{kind: {:watch_progress, id, _}}}, acc -> MapSet.put(acc, id)
        {_, %{kind: {:watch_updates, id, _, _, _}}}, acc -> MapSet.put(acc, id)
        _, acc -> acc
      end)

    not MapSet.member?(sessions, session_id) and
      MapSet.size(sessions) >= state.max_watched_sessions
  end

  # Progress is optional. Stop it at the diagnostic budget instead of evicting
  # terminal evidence and then accepting late Progress for an old Command.
  defp bound_diagnostics(state) do
    if state.progress_disabled or
         map_size(state.progress_sequences) + MapSet.size(state.settled_commands) > 4_096 do
      %{state | progress_disabled: true, progress_sequences: %{}, settled_commands: MapSet.new()}
    else
      state
    end
  end

  defp session_id(%ClientSession{id: id}), do: id
  defp session_id(id) when is_binary(id), do: id
  defp session_id(_value), do: nil

  defp attachment_id(%ClientAttachment{attachment_id: id}), do: id
  defp attachment_id(id) when is_binary(id), do: id
  defp attachment_id(_value), do: nil

  defp command_id(%ClientReceipt{command_id: id}), do: id
  defp command_id(%ClientTurnReceipt{command_id: id}), do: id
  defp command_id(id) when is_binary(id), do: id
  defp command_id(_value), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp enum_value(value) when is_atom(value), do: Atom.to_string(value)
  defp enum_value(value), do: value

  defp exact_keys?(map, keys) when is_map(map),
    do: Enum.sort(Map.keys(map)) == Enum.sort(keys)

  defp remaining(deadline),
    do: max(deadline - System.monotonic_time(:millisecond), 0)
end
