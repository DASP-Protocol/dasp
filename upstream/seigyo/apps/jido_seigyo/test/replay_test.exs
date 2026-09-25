defmodule Jido.Seigyo.ReplayTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Replay

  @session "ses_01994770-1234-7000-8000-000000000001"
  @command "cmd_01994770-1234-7000-8000-000000000002"

  defp update(sequence, state \\ "active") do
    %{
      "version" => 1,
      "session_id" => @session,
      "sequence" => sequence,
      "kind" => "event",
      "event_type" => "command_accepted",
      "command_id" => @command,
      "payload" => %{"kind" => "submit_text", "state" => state}
    }
  end

  test "SEIGYO-REPLAY-001: checking a value does not advance the applied cursor" do
    assert {:ok, replay} = Replay.new(@session)
    assert replay.cursor == 0
    assert {:ok, :apply} = Replay.check(replay, update(1))
    assert replay.cursor == 0
    assert {:error, %{code: "gap", field: "sequence"}} = Replay.check(replay, update(2))
    assert {:ok, advanced} = Replay.commit(replay, update(1))
    assert advanced.cursor == 1
    assert {:ok, :apply} = Replay.check(advanced, update(2))
  end

  test "SEIGYO-REPLAY-002: equivalent data is idempotent, conflicting data is a fault" do
    {:ok, replay} = Replay.new(@session)
    {:ok, replay} = Replay.commit(replay, update(1))
    reordered = update(1) |> Enum.reverse() |> Map.new()
    assert {:ok, :duplicate} = Replay.check(replay, reordered)
    assert {:ok, ^replay} = Replay.commit(replay, reordered)

    assert {:error, %{code: "conflict", field: "sequence"}} =
             Replay.check(replay, update(1, "queued"))

    assert {:error, %{code: "conflict"}} = Replay.commit(replay, update(1, "queued"))
  end

  test "SEIGYO-REPLAY-003: malformed and cross-Session Updates cannot advance a cursor" do
    {:ok, replay} = Replay.new(@session)

    for value <- [
          nil,
          %{},
          Map.put(update(1), "extra", nil),
          Map.put(update(1), "event_type", "unknown"),
          Map.put(update(1), "sequence", 9_007_199_254_740_992)
        ] do
      assert {:error, _} = Replay.check(replay, value)
      assert {:error, _} = Replay.commit(replay, value)
    end

    other = Map.put(update(1), "session_id", "ses_01994770-1234-7000-8000-000000000003")
    assert {:error, %{field: "session_id"}} = Replay.check(replay, other)
    assert replay.cursor == 0
  end

  test "SEIGYO-REPLAY-004: bounded evidence never makes an unverified duplicate safe" do
    {:ok, replay} = Replay.new(@session, window: 2)

    replay =
      Enum.reduce(1..4, replay, fn sequence, state ->
        {:ok, next} = Replay.commit(state, update(sequence))
        next
      end)

    assert map_size(replay.fingerprints) == 2
    assert {:ok, :duplicate} = Replay.check(replay, update(3))
    assert {:error, %{code: "gap", field: "sequence"}} = Replay.check(replay, update(1))
    {:ok, restored} = Replay.new(@session, after: 4)
    assert {:error, %{code: "gap"}} = Replay.check(restored, update(4))
    assert {:ok, :apply} = Replay.check(restored, update(5))
  end

  test "SEIGYO-REPLAY-004: construction rejects invalid identities, counters, and windows" do
    assert {:error, _} = Replay.new("bad")

    for opts <- [
          [after: -1],
          [after: 9_007_199_254_740_992],
          [after: 1.0],
          [window: 0],
          [window: 1001],
          [window: nil],
          [extra: true]
        ] do
      assert {:error, _} = Replay.new(@session, opts)
    end
  end

  test "SEIGYO-REPLAY-009: page cuts, duplicates, and partial application preserve state" do
    for count <- 1..20, page_size <- 1..count do
      {:ok, initial} = Replay.new(@session, window: 32)
      updates = Enum.map(1..count, &update/1)

      interrupted = div(count, 2)
      {saved, effects} = apply_values(Enum.take(updates, interrupted), {initial, []})
      # Application of the next item fails. Checking it cannot change the saved pair.
      assert {:ok, :apply} = Replay.check(saved, Enum.at(updates, interrupted))
      assert saved.cursor == interrupted

      deliveries = updates |> Enum.chunk_every(page_size) |> Enum.flat_map(&(&1 ++ &1))
      {replayed, actual} = apply_values(deliveries, {saved, effects})
      {continuous, expected} = apply_values(updates, {initial, []})
      assert actual == expected
      assert replayed == continuous
      assert actual == Enum.to_list(1..count)
    end
  end

  defp apply_values(updates, initial) do
    Enum.reduce(updates, initial, fn data, {replay, effects} ->
      case Replay.check(replay, data) do
        {:ok, :duplicate} ->
          {replay, effects}

        {:ok, :apply} ->
          next_effects = effects ++ [data["sequence"]]
          {:ok, next} = Replay.commit(replay, data)
          {next, next_effects}
      end
    end)
  end

  test "SEIGYO-REPLAY-009: published language-neutral vectors agree with the reference reducer" do
    vectors =
      Application.app_dir(:jido_seigyo, "priv/seigyo/replay-v1/vectors.json")
      |> File.read!()
      |> Jason.decode!()

    assert vectors["format"] == 1
    assert length(vectors["cases"]) == 6

    for vector <- vectors["cases"] do
      {:ok, replay} =
        Replay.new(vectors["session_id"], after: vector["after"], window: vector["window"])

      Enum.reduce(vector["steps"], replay, fn step, replay ->
        actual =
          case Replay.check(replay, step["update"]) do
            {:ok, action} -> Atom.to_string(action)
            {:error, error} -> error.code
          end

        assert actual == step["check"], vector["name"]

        next =
          if step["commit"] do
            {:ok, next} = Replay.commit(replay, step["update"])
            next
          else
            replay
          end

        assert next.cursor == step["cursor"], vector["name"]
        next
      end)
    end
  end
end
