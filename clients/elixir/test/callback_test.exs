defmodule DASP.CallbackTest do
  use ExUnit.Case, async: false

  @callback_timeout 1_000
  @callback_pause 1_200

  defp transport(callback, timeout) do
    {:ok, client} =
      DASP.Client.new(
        source: "urn:client",
        host_source: "urn:host",
        validate_profile: fn _ -> true end,
        transport: fn _, _ -> callback.() end,
        timeout: timeout
      )

    DASP.Client.open(client, %{
      "session_id" => "s",
      "actor_id" => "a",
      "profile" => %{"id" => "urn:profile", "version" => "1"}
    })
  end

  for boundary <- [:setup, :transport] do
    test "#{boundary} stops a callback when its caller exits" do
      parent = self()

      callback = fn ->
        send(parent, {:callback, self()})
        Process.sleep(:infinity)
      end

      owner =
        spawn(fn ->
          case unquote(boundary) do
            :setup ->
              DASP.WebSocket.setup(%{setup: fn _ -> callback.() end, setup_timeout: 5000}, %{})

            :transport ->
              transport(callback, 5000)
          end
        end)

      assert_receive {:callback, worker}, 1000
      monitor = Process.monitor(worker)
      Process.exit(owner, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^worker, :killed}, 1000
    end
  end

  test "a killed callback returns an error without killing its caller" do
    assert {:error, %DASP.Error{code: :transport, detail: :killed}} =
             transport(fn -> Process.exit(self(), :kill) end, 1000)

    assert {:error, %DASP.Error{code: :setup}} =
             DASP.WebSocket.setup(
               %{setup: fn _ -> Process.exit(self(), :kill) end, setup_timeout: 1000},
               %{}
             )
  end

  for completed_late <- [false, true] do
    test "callback completion time determines expiry when its caller is delayed: #{completed_late}" do
      parent = self()

      owner =
        spawn(fn ->
          result =
            DASP.Callback.run(
              fn ->
                send(parent, {:callback, self()})

                receive do
                  :finish -> :ok
                end
              end,
              @callback_timeout
            )

          send(parent, {:callback_result, result})
        end)

      assert_receive {:callback, worker}, 1000
      worker_ref = Process.monitor(worker)
      guard = callback_guard(owner, worker)
      :erlang.suspend_process(owner)
      :erlang.suspend_process(guard)

      try do
        pause_if(unquote(completed_late))
        send(worker, :finish)
        assert_receive {:DOWN, ^worker_ref, :process, ^worker, :normal}, 1000
        pause_if(unquote(not completed_late))
        :erlang.resume_process(owner)
        expected = if unquote(completed_late), do: :timeout, else: {:ok, :ok}
        assert_receive {:callback_result, ^expected}, 1000
        :erlang.resume_process(guard)
        guard_ref = Process.monitor(guard)
        assert_receive {:DOWN, ^guard_ref, :process, ^guard, _}, 1000
      after
        Process.exit(owner, :kill)
        Process.exit(guard, :kill)
        Process.exit(worker, :kill)
      end
    end
  end

  defp pause_if(true), do: Process.sleep(@callback_pause)
  defp pause_if(false), do: :ok

  defp callback_guard(owner, worker, attempts \\ 100) do
    guard =
      Enum.find(Process.list(), fn pid ->
        case Process.info(pid, :monitors) do
          {:monitors, monitors} ->
            MapSet.new(monitors) == MapSet.new([{:process, owner}, {:process, worker}])

          _ ->
            false
        end
      end)

    cond do
      guard ->
        guard

      attempts > 0 ->
        Process.sleep(1)
        callback_guard(owner, worker, attempts - 1)

      true ->
        flunk("Callback guard did not start.")
    end
  end
end
