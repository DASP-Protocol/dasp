defmodule DASP.SignalTest do
  use ExUnit.Case, async: true
  alias DASP.{Client, Wire, Checkpoint}
  alias Jido.Signal

  defp command do
    %{
      "specversion" => "1.0",
      "id" => "event-arbitrary-id",
      "source" => "urn:client:one",
      "type" => "dasp.v1.command",
      "datacontenttype" => "application/json",
      "requestid" => "attempt-1",
      "data" => %{
        "session_id" => "session-1",
        "command_id" => "command-1",
        "name" => "counter.add",
        "input" => %{"amount" => 3}
      }
    }
  end

  test "wire decoding uses Jido Signal and preserves all scalar extensions" do
    event =
      Map.merge(command(), %{
        "traceparent" => "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
        "traceflag" => false,
        "tracecount" => 7,
        "extensions" => "opaque-value",
        "time" => "2026-09-25T20:00:00.123Z",
        "subject" => "session-1",
        "dataschema" => "urn:schema:command"
      })

    assert {:ok, %Signal{} = signal} = Wire.decode(JSON.encode!(event))
    assert signal.specversion == "1.0"
    assert signal.id == event["id"]
    assert signal.extensions["requestid"] == "attempt-1"
    assert signal.extensions["extensions"] == "opaque-value"
    assert signal.extensions["traceflag"] == false
    assert {:ok, encoded} = Wire.encode(signal)
    assert JSON.decode!(encoded) == event
    assert {:ok, ^event} = Wire.to_map(signal)
  end

  test "RFC 3339 timestamps retain valid lowercase and leap-second spellings" do
    for time <- ["2026-09-25t20:00:00z", "2016-12-31T23:59:60Z", "2017-01-01T00:59:60.5+01:00"] do
      event = Map.put(command(), "time", time)
      assert {:ok, signal} = Wire.to_signal(event)
      assert signal.time == time
      assert {:ok, encoded} = Wire.encode(signal)
      assert JSON.decode!(encoded) == event
    end

    for time <- [
          "2026-02-31T20:00:00Z",
          "2026-09-25T20:00:00+25:00",
          "2016-12-31T22:59:60Z",
          "2016-12-31T23:59:61Z",
          "2026-09-25T24:00:00Z"
        ] do
      assert {:error, %DASP.Error{}} = Wire.to_signal(Map.put(command(), "time", time))
    end
  end

  test "URI attributes reject malformed percent escapes" do
    for key <- ["source", "dataschema"],
        uri <- ["urn:a%zz", "https://example.com/%", "urn:a%0"] do
      assert {:error, %DASP.Error{}} = Wire.to_signal(Map.put(command(), key, uri))
    end

    assert {:ok, _} = Wire.to_signal(Map.put(command(), "source", "https://example.com/a%20b"))
  end

  test "decoding does not invent a timestamp or require a Jido-generated event ID" do
    assert {:ok, signal} = Wire.to_signal(command())
    assert signal.time == nil
    assert signal.id == "event-arbitrary-id"
    assert {:ok, encoded} = Wire.encode(signal)
    refute Map.has_key?(JSON.decode!(encoded), "time")
  end

  test "native Jido signals encode as DASP CloudEvents 1.0" do
    data = command()["data"]

    signal =
      Signal.new!("dasp.v1.command", data,
        source: "urn:client:one",
        datacontenttype: "application/json",
        extensions: %{"requestid" => "attempt-native"}
      )

    assert {:ok, wire} = Wire.encode(signal)

    assert %{"specversion" => "1.0", "requestid" => "attempt-native", "data" => ^data} =
             JSON.decode!(wire)

    assert {:ok, decoded} = Wire.decode(wire)
    assert decoded == signal
  end

  test "core collisions, unsupported versions, and local dispatch never enter the wire" do
    {:ok, signal} = Wire.to_signal(command())

    for changed <- [
          %{signal | extensions: Map.put(signal.extensions, "source", "urn:other")},
          %{signal | extensions: Map.put(signal.extensions, "custom", %{"nested" => true})},
          %{signal | extensions: %{requestid: "atom-key"}},
          %{signal | specversion: "2.0"},
          %{signal | data_base64?: true}
        ] do
      assert {:error, %DASP.Error{}} = Wire.encode(changed)
    end

    assert {:error, _} =
             command() |> Map.put("specversion", "1.0.2") |> JSON.encode!() |> Wire.decode()
  end

  test "client callbacks and replies use signals, while the transport uses DASP JSON" do
    parent = self()

    {:ok, client} =
      Client.new(
        source: "urn:client:one",
        host_source: "urn:host:one",
        validate_profile: fn %Signal{} = signal ->
          send(parent, {:validated, signal})
          true
        end,
        transport: fn wire, _ ->
          request = JSON.decode!(wire)
          send(parent, {:request, request})

          signal =
            Signal.new!(
              "dasp.v1.receipt",
              %{
                "session_id" => "session-1",
                "command_id" => "command-1",
                "disposition" => "accepted",
                "admission_sequence" => 1,
                "error" => nil
              },
              source: "urn:host:one",
              datacontenttype: "application/json",
              extensions: %{"requestid" => request["requestid"]}
            )

          Wire.encode(signal)
        end
      )

    session = %{
      "session_id" => "session-1",
      "actor_id" => "actor-1",
      "profile" => %{"id" => "urn:counter", "version" => "1"}
    }

    assert {:ok, %Signal{type: "dasp.v1.receipt"}} =
             Client.submit(client, session, Map.drop(command()["data"], ["session_id"]))

    assert_receive {:request, %{"specversion" => "1.0"} = request}
    assert Signal.ID.valid?(request["id"])
    assert Signal.ID.valid?(request["requestid"])
    assert_receive {:validated, %Signal{type: "dasp.v1.command"}}
    assert_receive {:validated, %Signal{type: "dasp.v1.receipt"}}
  end

  test "signal recovery preserves portable checkpoint evidence" do
    {:ok, view} =
      Wire.to_signal(%{
        "specversion" => "1.0",
        "id" => "view-1",
        "source" => "urn:host:one",
        "type" => "dasp.v1.view",
        "datacontenttype" => "application/json",
        "requestid" => "view-attempt",
        "data" => %{
          "session_id" => "session-1",
          "actor_id" => "actor-1",
          "profile" => %{"id" => "urn:counter", "version" => "1"},
          "cursor" => 0,
          "state" => %{"value" => 0}
        }
      })

    event = %{
      "specversion" => "1.0",
      "id" => "update-1",
      "source" => "urn:host:one",
      "type" => "dasp.v1.update",
      "datacontenttype" => "application/json",
      "data" => %{
        "session_id" => "session-1",
        "sequence" => 1,
        "kind" => "application",
        "command_id" => nil,
        "payload" => %{"name" => "counter.changed", "data" => %{"value" => 3}}
      }
    }

    {:ok, update} = Wire.to_signal(event)
    validator = fn %Signal{} -> true end
    reducer = fn _state, %Signal{data: data} -> data["payload"]["data"] end
    {:ok, checkpoint} = Checkpoint.from_view(view, validator)
    assert {:ok, saved} = Checkpoint.apply_updates(checkpoint, [update], reducer, validator)
    restored = saved |> JSON.encode!() |> JSON.decode!()
    assert restored["state"] == %{"value" => 3}
    assert restored["evidence"]["1"]["id"] == event["id"]
    assert {:ok, ^restored} = Checkpoint.apply_updates(restored, [event], reducer, validator)

    assert {:error, %DASP.Error{code: :changed_update}} =
             Checkpoint.apply_updates(restored, [%{update | id: "changed"}], reducer, validator)
  end
end
