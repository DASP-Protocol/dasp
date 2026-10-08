defmodule DASP do
  @moduledoc """
  DASP draft-01 client built on Jido Signal, Zoi, and Mint WebSocket.

  connect/2 starts an optional managed client. DASP.Connection provides the
  same connection engine for an existing owning process. Core signals are
  ordinary Jido.Signal values made with the DASP.Signal modules.

  A command request returns its admission receipt, including a rejection.
  A protocol Failure is also an {:ok, signal} reply. Local errors return
  {:error, DASP.Error}. No automatic retry, reconnect, or cursor change occurs.
  """
  alias DASP.{Managed, Subscription}
  @enforce_keys [:pid, :budget, :max_queued_messages, :max_queued_bytes, :close_timeout]
  defstruct [:pid, :budget, :max_queued_messages, :max_queued_bytes, :close_timeout]

  def connect(url, opts) do
    with true <- is_list(opts) and Keyword.keyword?(opts),
         {:ok, pid} <- Managed.start(Keyword.put(opts, :url, url)) do
      Managed.handle(pid)
    else
      false ->
        {:error, %DASP.Error{code: :configuration, message: "Supply keyword connection options."}}

      error ->
        error
    end
  end

  defdelegate start_link(opts), to: Managed
  defdelegate child_spec(opts), to: Managed
  @doc "Get a public handle for a supervised client PID or name."
  defdelegate connection(client), to: Managed, as: :handle
  def request(client, signal, opts \\ []), do: Managed.request(client, signal, opts, :sync)
  @doc "Accept a local request. Take its one terminal result with await/3. Results are bounded."
  def request_async(client, signal, opts \\ []), do: Managed.request(client, signal, opts, :async)
  def await(client, local_ref, opts \\ []), do: Managed.await(client, local_ref, opts)
  @doc "Activate a subscription now, including before session.open."
  def subscribe(client, opts), do: Managed.subscribe(client, opts)
  def next(subscription, opts \\ []), do: Managed.next(subscription, opts)
  def unsubscribe(subscription), do: Managed.unsubscribe(subscription)

  @doc "Make a lazy stream. A new subscription activates when enumeration starts."
  def signals(client, opts) do
    Stream.resource(
      fn ->
        case subscribe(client, opts) do
          {:ok, sub} -> sub
          {:error, error} -> raise error
        end
      end,
      &stream_next/1,
      &unsubscribe/1
    )
  end

  @doc "Enumerate an existing subscription. Enumeration releases it on stop."
  def signals(%Subscription{} = subscription),
    do: Stream.resource(fn -> subscription end, &stream_next/1, &unsubscribe/1)

  defp stream_next(sub) do
    case next(sub) do
      {:ok, signal} -> {[signal], sub}
      {:error, %{code: :wait_timeout}} -> {[], sub}
      {:error, error} -> raise error
    end
  end

  def drain(client, opts \\ []), do: Managed.drain(client, opts)
  def close(client), do: Managed.close(client)
  defdelegate encode(signal), to: DASP.Wire
  defdelegate decode(json), to: DASP.Wire
end
