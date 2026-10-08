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

  test "native constructors keep identifier and name boundaries across message types" do
    fixtures =
      Path.expand("../../../specification/draft-01/examples/counter.json", __DIR__)
      |> File.read!()
      |> JSON.decode!()

    for event <- fixtures,
        key <- ~w(session_id actor_id command_id name),
        is_binary(event["data"][key]) do
      module = DASP.Signal.module(event["type"])

      for value <- ["a", String.duplicate("a", 128)] do
        data = Map.put(event["data"], key, value)

        assert {:ok, %Signal{data: ^data}} =
                 apply(module, :new, [data, [source: event["source"]]])
      end

      for value <- ["", "a\n", "a b", String.duplicate("a", 129)] do
        assert {:error, _} =
                 apply(module, :new, [
                   Map.put(event["data"], key, value),
                   [source: event["source"]]
                 ])
      end
    end

    for name <- ["9work", "Work", "work/run"] do
      assert {:error, _} =
               DASP.Signal.Command.new(Map.put(command()["data"], "name", name),
                 source: "urn:client:one"
               )
    end
  end

  test "shared fields preserve required null values and closed nested objects" do
    data = %{
      "session_id" => "one",
      "command_id" => nil,
      "name" => "work",
      "payload" => %{}
    }

    assert {:ok, _} = DASP.Signal.Progress.new(data, source: "urn:host:one")

    assert {:error, _} =
             DASP.Signal.Progress.new(Map.delete(data, "command_id"), source: "urn:host:one")

    session = %{
      "session_id" => "one",
      "actor_id" => "actor",
      "profile" => %{"id" => "urn:profile:one", "version" => "1"}
    }

    assert {:ok, _} = DASP.Signal.SessionOpen.new(session, source: "urn:client:one")

    for profile <- [
          %{"id" => "urn:profile:one", "version" => ""},
          %{"id" => "urn:profile:one", "version" => "1", "extra" => true}
        ] do
      assert {:error, _} =
               DASP.Signal.SessionOpen.new(Map.put(session, "profile", profile),
                 source: "urn:client:one"
               )
    end

    error = %{"code" => "denied", "message" => "Denied", "retryable" => false}
    assert {:ok, _} = DASP.Signal.Failure.new(%{"error" => error}, source: "urn:host:one")

    for error <- [Map.put(error, "extra", true), Map.put(error, "code", "Denied")] do
      assert {:error, _} = DASP.Signal.Failure.new(%{"error" => error}, source: "urn:host:one")
    end
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
          "2016-12-30T23:59:60Z",
          "2016-12-31T00:59:60+01:00",
          "2016-12-31T23:59:61Z",
          "2026-09-25T24:00:00Z"
        ] do
      assert {:error, %DASP.Error{}} = Wire.to_signal(Map.put(command(), "time", time))
    end
  end

  test "CloudEvents context strings reject controls and Unicode noncharacters" do
    noncharacters = for plane <- 0..16, ending <- [0xFFFE, 0xFFFF], do: plane * 0x10000 + ending

    invalid =
      Enum.to_list(0..0x1F) ++
        Enum.to_list(0x7F..0x9F) ++ Enum.to_list(0xFDD0..0xFDEF) ++ noncharacters

    failure =
      command()
      |> Map.put("type", "dasp.v1.failure")
      |> Map.put("data", %{
        "error" => %{"code" => "denied", "message" => "Denied", "retryable" => false}
      })

    for char <- invalid,
        {event, key} <- [{command(), "id"}, {command(), "trace"}, {failure, "subject"}] do
      changed = Map.put(event, key, "value" <> <<char::utf8>>)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.encode(changed)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.to_map(changed)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.to_signal(changed)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.decode(JSON.encode!(changed))
    end

    signal = Wire.to_signal!(command())
    failure_signal = Wire.to_signal!(failure)

    for changed <- [
          %{signal | id: "bad\n"},
          %{signal | extensions: Map.put(signal.extensions, "trace", "bad\0")},
          %{failure_signal | subject: "bad" <> <<0x10FFFF::utf8>>}
        ] do
      assert {:error, %DASP.Error{code: :invalid_event}} = DASP.encode(changed)
    end
  end

  test "valid context characters and arbitrary application strings retain their values" do
    for char <- [
          0x20,
          0x7E,
          0xA0,
          0xFDCF,
          0xFDF0,
          0xFEFF,
          0x2028,
          0x2029,
          0xFFFD,
          0x1FFFD,
          0x10FFFD
        ] do
      value = "value" <> <<char::utf8>>
      event = Map.merge(command(), %{"id" => value, "trace" => value})
      assert {:ok, signal} = Wire.to_signal(event)
      assert {:ok, encoded} = Wire.encode(signal)
      assert JSON.decode!(encoded) == event
    end

    text = "\0\n" <> <<0x7F::utf8, 0x9F::utf8, 0xFDD0::utf8, 0x10FFFF::utf8>>
    event = put_in(command(), ["data", "input"], %{"text" => text})
    assert {:ok, signal} = Wire.to_signal(event)
    assert {:ok, encoded} = Wire.encode(signal)
    assert {:ok, ^signal} = Wire.decode(encoded)
  end

  test "dataschema excludes fragments without narrowing source URI references" do
    signal = Wire.to_signal!(command())

    for uri <- ["urn:schema:one#part", "urn:schema:one#"] do
      event = Map.put(command(), "dataschema", uri)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.to_signal(event)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.decode(JSON.encode!(event))
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.encode(event)

      assert {:error, %DASP.Error{code: :invalid_event}} =
               DASP.encode(%{signal | dataschema: uri})
    end

    for uri <- ["about:", "dav:", "urn:schema:one?version=2", "urn:schema:one%23part"] do
      event = Map.merge(command(), %{"source" => "urn:client:one#part", "dataschema" => uri})
      assert {:ok, signal} = Wire.to_signal(event)
      assert {:ok, encoded} = Wire.encode(signal)
      assert JSON.decode!(encoded) == event
    end
  end

  test "saved nested Updates enforce the same context string and schema URI rules" do
    page =
      Path.expand("../../../specification/draft-01/examples/counter.json", __DIR__)
      |> File.read!()
      |> JSON.decode!()
      |> Enum.find(&(&1["type"] == "dasp.v1.updates"))

    [first | rest] = page["data"]["events"]

    for {key, value} <- [{"id", "bad\n"}, {"trace", "bad\0"}, {"dataschema", "urn:schema:one#"}] do
      data = Map.put(page["data"], "events", [Map.put(first, key, value) | rest])
      event = Map.put(page, "data", data)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.encode(event)
      assert {:error, %DASP.Error{code: :invalid_event}} = Wire.decode(JSON.encode!(event))
      assert {:error, _} = DASP.Signal.Updates.new(data, source: page["source"])
    end
  end

  test "URI attributes reject malformed percent escapes" do
    for key <- ["source", "dataschema"],
        uri <- ["urn:a%zz", "https://example.com/%", "urn:a%0"] do
      assert {:error, %DASP.Error{}} = Wire.to_signal(Map.put(command(), key, uri))
    end

    assert {:ok, _} = Wire.to_signal(Map.put(command(), "source", "https://example.com/a%20b"))
  end

  test "absolute URI attributes allow an empty path" do
    for key <- ["source", "dataschema"], uri <- ["about:", "dav:"] do
      event = Map.put(command(), key, uri)
      assert {:ok, signal} = Wire.to_signal(event)
      assert Wire.to_map!(signal) == event
    end

    assert {:ok, _} =
             DASP.Signal.SessionOpen.new(
               %{
                 "session_id" => "s",
                 "actor_id" => "a",
                 "profile" => %{"id" => "dav:", "version" => "1"}
               },
               source: "about:"
             )
  end

  test "native Updates returns validation errors for improper event lists" do
    fixture =
      Path.expand("../../../specification/draft-01/examples/counter.json", __DIR__)
      |> File.read!()
      |> JSON.decode!()
      |> Enum.find(&(&1["type"] == "dasp.v1.updates"))

    for events <- [[1 | :bad], [hd(fixture["data"]["events"]) | :bad]] do
      data = Map.put(fixture["data"], "events", events)
      assert {:error, _} = DASP.Signal.Updates.new(data, source: fixture["source"])
      assert {:error, _} = DASP.Signal.Updates.validate_data(data)

      assert_raise Zoi.ParseError, fn ->
        DASP.Signal.Updates.new!(data, source: fixture["source"])
      end
    end
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
