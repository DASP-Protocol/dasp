defmodule DASP.Callback do
  @moduledoc false

  # Keep a blocking callback within its caller's lifetime and deadline, without
  # linking callback faults to the caller. The alias discards late results.
  def run(fun, timeout) do
    caller = self()
    tag = :erlang.alias()
    expires = now() + timeout

    {worker, ref} =
      spawn_monitor(fn ->
        guard(caller, self(), expires)
        result = fun.()
        send(tag, {tag, result, now()})
      end)

    try do
      await_result(tag, ref, worker, expires)
    after
      :erlang.unalias(tag)
      Process.exit(worker, :kill)
      Process.demonitor(ref, [:flush])

      receive do
        {^tag, _, _} -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp await_result(tag, ref, worker, expires) do
    receive do
      {^tag, result, completed} ->
        completion_result(result, completed, expires)

      {:DOWN, ^ref, :process, ^worker, reason} ->
        if now() >= expires, do: :timeout, else: {:exit, reason}
    after
      max(0, expires - now()) -> queued_completion(tag, expires)
    end
  end

  # OTP can select an expired receive timeout before it processes a result that
  # was queued while this process was suspended. The worker timestamp keeps the
  # decision tied to callback completion instead of caller scheduling.
  defp queued_completion(tag, expires) do
    receive do
      {^tag, result, completed} -> completion_result(result, completed, expires)
    after
      0 -> :timeout
    end
  end

  defp completion_result(result, completed, expires) do
    if completed < expires, do: {:ok, result}, else: :timeout
  end

  defp guard(caller, worker, expires) do
    spawn(fn ->
      caller_ref = Process.monitor(caller)
      worker_ref = Process.monitor(worker)

      receive do
        {:DOWN, ^caller_ref, :process, ^caller, _} -> Process.exit(worker, :kill)
        {:DOWN, ^worker_ref, :process, ^worker, _} -> :ok
      after
        max(0, expires - now()) -> Process.exit(worker, :kill)
      end
    end)
  end

  defp now, do: System.monotonic_time(:millisecond)
end
