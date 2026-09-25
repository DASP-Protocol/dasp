defmodule DASP.ClientTest do
  use ExUnit.Case, async: true
  alias DASP.{Client, Wire, Checkpoint}

  test "update byte limits include whitespace inside replay pages" do
    update = Jason.encode!(step("admission"))
    padded = String.replace_prefix(update, "{", "{" <> String.duplicate(" ", 65_536))
    assert {:error, _} = Wire.decode(padded)

    page =
      step("page-two")
      |> put_in(["data", "events"], [step("admission")])
      |> put_in(["data", "next"], 1)

    assert {:error, _} = Wire.decode(String.replace(Jason.encode!(page), update, padded))
  end

  @root Path.expand("../../..", __DIR__)
  @valid File.read!(Path.join(@root, "specification/draft-01/examples/counter.json"))
         |> Jason.decode!()
  @invalid File.read!(Path.join(@root, "conformance/fixtures/invalid-events.json"))
           |> Jason.decode!()
  @trace File.read!(Path.join(@root, "conformance/fixtures/recovery-trace.json"))
         |> Jason.decode!()
  defp step(id), do: Enum.find(@trace["steps"], &(&1["id"] == id))["event"]
  defp session, do: step("open")["data"]
  defp profile(%Jido.Signal{}), do: true

  defp client(transport, opts \\ []) do
    {:ok, c} =
      Client.new(
        Keyword.merge(
          [
            source: "urn:example:client:one",
            host_source: "urn:example:host:one",
            validate_profile: &profile/1,
            transport: transport
          ],
          opts
        )
      )

    c
  end

  defp reply(wire, id) do
    request = Jason.decode!(wire)
    {:ok, step(id) |> Map.put("requestid", request["requestid"]) |> Jason.encode!()}
  end

  defp submit(c),
    do: Client.submit(c, session(), Map.drop(step("command")["data"], ["session_id"]))

  defp reduce(state, %Jido.Signal{
         data: %{"kind" => "application", "payload" => %{"data" => data}}
       }),
       do: Map.merge(state, data)

  defp reduce(state, _), do: state

  defp checkpoint(cursor \\ 0, state \\ %{"value" => 0}) do
    view =
      step("opened")
      |> Map.put("type", "dasp.view.v1")
      |> Map.put("data", Map.merge(session(), %{"cursor" => cursor, "state" => state}))

    {:ok, saved} = Checkpoint.from_view(view, &profile/1)
    saved
  end

  for {event, index} <- Enum.with_index(@valid) do
    test "valid draft event #{index}" do
      event = unquote(Macro.escape(event))
      assert {:ok, json} = Wire.encode(event)
      assert {:ok, %Jido.Signal{} = signal} = Wire.decode(json)
      assert {:ok, ^event} = Wire.to_map(signal)
    end
  end

  for vector <- @invalid do
    test "reject draft vector #{vector["id"]}" do
      assert {:error, %DASP.Error{}} =
               Wire.decode(Jason.encode!(unquote(Macro.escape(vector["event"]))))
    end
  end

  for token <- [
        "0.5",
        "1.00000000000000001",
        "9007199254740992",
        "9.0071992547409911e15",
        "1e99999",
        "1e-99999"
      ] do
    test "reject exact nonportable number #{token}" do
      text =
        step("command")
        |> Jason.encode!()
        |> String.replace(~s("amount":3), ~s("amount":) <> unquote(token))

      assert {:error, %DASP.Error{}} = Wire.decode(text)
    end
  end

  test "integer exponent and decimal notation retain exact values" do
    for token <- ["3.0", "30e-1", "0.003e3"] do
      text =
        step("command")
        |> Jason.encode!()
        |> String.replace(~s("amount":3), ~s("amount":) <> token)

      assert {:ok, event} = Wire.decode(text)
      assert event.data["input"]["amount"] == 3
    end
  end

  test "reject duplicate keys, invalid Unicode, and lossy local values" do
    text = Jason.encode!(step("command"))

    for bad <- [
          String.replace(text, ~s("amount":3), ~S("amount":3,"\u0061mount":4)),
          String.replace(text, ~s("amount":3), ~S("amount":"\ud800")),
          <<255>>,
          text <> " null",
          String.duplicate(" ", 1_048_577)
        ],
        do: assert({:error, %DASP.Error{}} = Wire.decode(bad))

    for value <- [1.5, self(), %{atom_key: 1}, Date.utc_today()] do
      assert {:error, %DASP.Error{}} =
               Wire.encode(put_in(step("command"), ["data", "input", "amount"], value))
    end
  end

  test "subject and payload limits are enforced" do
    assert {:error, _} = Wire.encode(Map.put(step("command"), "subject", "other"))

    for input <- [
          %{"text" => String.duplicate("x", 65_537)},
          %{"items" => List.duplicate(0, 1025)},
          Enum.reduce(1..16, %{}, fn _, acc -> %{"nested" => acc} end)
        ] do
      assert {:error, _} = Wire.encode(put_in(step("command"), ["data", "input"], input))
    end
  end

  test "lost receipt retry preserves command identity and changes attempt identity" do
    {:ok, state} = Agent.start_link(fn -> [] end)

    c =
      client(fn wire, _ ->
        requests =
          Agent.get_and_update(state, fn requests ->
            {requests, requests ++ [Jason.decode!(wire)]}
          end)

        if requests == [], do: {:error, :lost_connection}, else: reply(wire, "duplicate")
      end)

    assert {:error, %DASP.Error{code: :transport}} = submit(c)
    assert {:ok, %Jido.Signal{data: %{"disposition" => "duplicate"} = data}} = submit(c)
    refute Map.has_key?(data, "outcome")
    [first, second] = Agent.get(state, & &1)
    assert first["data"] == second["data"]
    refute first["requestid"] == second["requestid"]
    refute first["id"] == second["id"]
    Agent.stop(state)
  end

  test "open, view, and outcome are distinct APIs" do
    assert {:ok, %Jido.Signal{data: %{"cursor" => 0}}} =
             Client.open(client(fn w, _ -> reply(w, "opened") end), session())

    assert {:ok, %Jido.Signal{data: %{"state" => "settled"}}} =
             Client.read_outcome(
               client(fn w, _ -> reply(w, "outcome") end),
               session(),
               "command-add-1"
             )

    c =
      client(fn wire, _ ->
        {:ok, json} = reply(wire, "opened")
        event = json |> Jason.decode!() |> Map.put("type", "dasp.view.v1")
        {:ok, event |> put_in(["data", "state"], %{"value" => 0}) |> Jason.encode!()}
      end)

    assert {:ok, %Jido.Signal{data: %{"state" => %{"value" => 0}}}} =
             Client.read_view(c, session())
  end

  test "timeout stops the adapter without retrying or reporting rejection" do
    parent = self()

    c =
      client(
        fn _, _ ->
          send(parent, {:worker, self()})
          Process.sleep(:infinity)
        end,
        timeout: 10
      )

    assert {:error, %DASP.Error{code: :timeout}} = submit(c)
    assert_receive {:worker, pid}
    monitor = Process.monitor(pid)
    assert_receive {:DOWN, ^monitor, :process, ^pid, _}
    refute_receive {:worker, _}
  end

  test "adapter crash returns a transport error" do
    assert {:error, %DASP.Error{code: :transport}} =
             submit(client(fn _, _ -> raise "connection failed" end))
  end

  test "reply context must match" do
    for path <- [["requestid"], ["source"], ["data", "session_id"], ["data", "command_id"]] do
      c =
        client(fn wire, _ ->
          {:ok, json} = reply(wire, "duplicate")
          {:ok, json |> Jason.decode!() |> put_in(path, "urn:other:value") |> Jason.encode!()}
        end)

      assert {:error, %DASP.Error{code: :correlation}} = submit(c)
    end
  end

  test "profile rejection stops sending and nested replay" do
    c = client(fn _, _ -> flunk("must not send") end, validate_profile: fn _ -> false end)
    assert {:error, %DASP.Error{code: :profile}} = submit(c)

    c =
      client(fn wire, _ -> reply(wire, "page-two") end,
        validate_profile: &(&1.type != "dasp.update.v1")
      )

    assert {:error, %DASP.Error{code: :profile}} = Client.read_updates(c, session(), 0)
  end

  test "replay validates bounds, contiguity, session, source, and limit" do
    changes = [
      fn e -> put_in(e, ["data", "after"], 1) end,
      fn e -> put_in(e, ["data", "next"], 2) end,
      fn e -> put_in(e, ["data", "head"], 2) end,
      fn e -> put_in(e, ["data", "events"], []) end,
      fn e ->
        update_in(
          e,
          ["data", "events"],
          &List.update_at(&1, 1, fn x -> put_in(x, ["data", "sequence"], 3) end)
        )
      end,
      fn e ->
        update_in(
          e,
          ["data", "events"],
          &List.update_at(&1, 0, fn x -> put_in(x, ["data", "session_id"], "other") end)
        )
      end,
      fn e ->
        update_in(
          e,
          ["data", "events"],
          &List.update_at(&1, 0, fn x -> Map.put(x, "source", "urn:other:host") end)
        )
      end
    ]

    for change <- changes do
      c =
        client(fn wire, _ ->
          {:ok, json} = reply(wire, "page-two")
          {:ok, json |> Jason.decode!() |> change.() |> Jason.encode!()}
        end)

      assert {:error, _} = Client.read_updates(c, session(), 0)
    end

    assert {:error, %DASP.Error{code: :replay}} =
             Client.read_updates(client(fn w, _ -> reply(w, "page-two") end), session(), 0, 1)
  end

  for consumer <- @trace["clients"] do
    test "recover recorded client #{consumer["id"]}" do
      consumer = unquote(Macro.escape(consumer))
      start = checkpoint(consumer["initial"]["cursor"], consumer["initial"]["state"])
      c = client(fn wire, _ -> reply(wire, consumer["page"]) end)
      assert {:ok, page} = Client.read_updates(c, session(), start["cursor"])

      assert {:ok, saved} =
               Checkpoint.apply_updates(start, page.data["events"], &reduce/2, &profile/1)

      assert Map.take(saved, ["cursor", "state"]) == consumer["expected"]
      restored = saved |> Jason.encode!() |> Jason.decode!()

      assert {:ok, ^restored} =
               Checkpoint.apply_updates(restored, page.data["events"], &reduce/2, &profile/1)
    end
  end

  test "gaps, changed duplicates, and missing evidence stop advancement" do
    start = checkpoint()

    assert {:error, %DASP.Error{code: :gap}} =
             Checkpoint.apply_updates(start, [step("state")], &reduce/2, &profile/1)

    assert {:ok, saved} =
             Checkpoint.apply_updates(start, [step("admission")], &reduce/2, &profile/1)

    changed = Map.put(step("admission"), "id", "changed")

    assert {:error, %DASP.Error{code: :changed_update}} =
             Checkpoint.apply_updates(saved, [changed], &reduce/2, &profile/1)

    assert {:error, %DASP.Error{code: :missing_evidence}} =
             Checkpoint.apply_updates(checkpoint(1), [step("admission")], &reduce/2, &profile/1)

    assert {:error, %DASP.Error{code: :checkpoint}} =
             Checkpoint.apply_updates(start, [step("lost-receipt")], &reduce/2, &profile/1)

    assert start["cursor"] == 0
  end
end
