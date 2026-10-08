defmodule DASP.Examples.SocketOwner do
  @moduledoc """
  An application process which owns a functional DASP connection.
  It starts no DASP server process. Its local signal queue is bounded.
  Use the managed DASP API when this application process is not needed.
  """
  use GenServer
  alias DASP.{Connection, Error, Wire}

  def start_link(url, opts), do: GenServer.start_link(__MODULE__, {url, opts})

  def request(pid, signal, opts \\ []),
    do: GenServer.call(pid, {:request, signal, opts}, :infinity)

  def next(pid), do: GenServer.call(pid, :next)

  @impl true
  def init({url, opts}) do
    case Connection.connect(url, opts) do
      {:ok, connection} ->
        {:ok,
         %{
           connection: connection,
           pending: %{},
           queue: :queue.new(),
           count: 0,
           bytes: 0,
           failure: nil,
           timer: nil
         }}

      {:error, error} ->
        {:stop, error}
    end
  end

  @impl true
  def handle_call({:request, signal, opts}, from, state) do
    case Connection.request(state.connection, signal, opts) do
      {:ok, connection, ref} ->
        next = %{state | connection: connection, pending: Map.put(state.pending, ref, from)}
        {:noreply, schedule(next)}

      {:error, connection, error} ->
        {:reply, {:error, error}, schedule(%{state | connection: connection})}
    end
  end

  def handle_call(:next, _, %{failure: error} = state) when not is_nil(error),
    do: {:reply, {:error, error}, state}

  def handle_call(:next, _, state) do
    case :queue.out(state.queue) do
      {{:value, {signal, bytes}}, queue} ->
        {:reply, {:ok, signal},
         %{state | queue: queue, count: state.count - 1, bytes: state.bytes - bytes}}

      {:empty, _} ->
        {:reply, :empty, state}
    end
  end

  @impl true
  def handle_info(:dasp_deadline, state) do
    {:ok, connection, events} = Connection.tick(state.connection)
    {:noreply, dispatch(%{state | connection: connection, timer: nil}, events) |> schedule()}
  end

  # Place the application's other handle_info clauses before this clause.
  def handle_info(message, state) do
    case Connection.stream(state.connection, message) do
      :unknown ->
        {:noreply, state}

      {:ok, connection, events} ->
        {:noreply, dispatch(%{state | connection: connection}, events) |> schedule()}
    end
  end

  defp dispatch(state, events), do: Enum.reduce(events, state, &event/2)

  defp event({:reply, ref, result}, state) do
    {from, pending} = Map.pop(state.pending, ref)
    if from, do: GenServer.reply(from, result)
    %{state | pending: pending}
  end

  defp event({:signal, signal}, state) do
    bytes = byte_size(Wire.encode!(signal))

    if state.count >= 100 or state.bytes + bytes > 1_048_576 do
      error = %Error{
        code: :delivery_overflow,
        message: "Local delivery queue overflow. Recover from the applied cursor."
      }

      {:ok, connection, events} = Connection.close(state.connection, error)
      dispatch(%{state | connection: connection}, events)
    else
      %{
        state
        | queue: :queue.in({signal, bytes}, state.queue),
          count: state.count + 1,
          bytes: state.bytes + bytes
      }
    end
  end

  defp event({:error, error}, state),
    do: %{state | failure: error, queue: :queue.new(), count: 0, bytes: 0}

  defp schedule(state) do
    if state.timer, do: Process.cancel_timer(state.timer)

    timer =
      case Connection.next_timeout(state.connection) do
        :infinity -> nil
        milliseconds -> Process.send_after(self(), :dasp_deadline, milliseconds)
      end

    %{state | timer: timer}
  end

  @impl true
  def terminate(_, state) do
    Connection.close(state.connection)
    :ok
  end
end
