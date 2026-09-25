defmodule Jido.Seigyo.ReleaseTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo
  alias Jido.Seigyo.{Digest, Release, Trace, Update}

  test "release signal schemas cover the advertised coding v1 catalog" do
    schemas = Release.schemas()["signals"]

    advertised =
      Seigyo.request_signal_types() ++
        Seigyo.result_signal_types() ++ Seigyo.push_signal_types()

    assert Enum.sort(Map.keys(schemas)) == Enum.sort(advertised)

    assert Enum.all?(schemas, fn {type, entry} ->
             schema = entry["schema"]

             schema["additionalProperties"] == false and
               schema["properties"]["type"] == %{"const" => type} and
               schema["required"] == ~w(specversion id source type data)
           end)
  end

  test "release operations cover the advertised operation catalog in order" do
    operations = Release.manifest()["operations"]

    assert Enum.map(operations, & &1["name"]) == Seigyo.operations()
    assert Enum.all?(operations, &is_binary(&1["result_signal_type"]))

    assert Enum.find(operations, &(&1["name"] == "submit"))["failure_delivery"] ==
             ["failure", "rejected_receipt"]

    assert Enum.find(operations, &(&1["name"] == "view"))["input"] == "args"

    assert Enum.find(operations, &(&1["name"] == "view"))["args_schema"] == %{
             "$schema" => "https://json-schema.org/draft/2020-12/schema",
             "type" => "object",
             "additionalProperties" => false,
             "required" => ["session_id"],
             "properties" => %{
               "session_id" => %{
                 "type" => "string",
                 "pattern" =>
                   "^ses_[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
               }
             }
           }

    assert Enum.all?(operations, fn operation ->
             operation["input"] == "signal" or is_map(operation["args_schema"])
           end)
  end

  test "release frames and limits fix the portable WebSocket boundary" do
    frames = Release.frames()
    manifest = Release.manifest()

    assert frames["join"]["request"] ==
             ["1", "1", "client:v1", "phx_join", %{"version" => 1, "profile" => "coding"}]

    assert manifest["transport"]["http"] == false
    assert manifest["limits"]["signal_json_bytes"] == 512_000
    assert manifest["limits"]["updates_page_json_bytes"] == 262_144
    assert manifest["limits"]["page_items"] == 100
  end

  test "release helpers expose all roles and terminal variants" do
    modules = Release.signal_modules()

    assert Enum.count(modules, &(elem(&1, 0) == :request)) == 11
    assert Enum.count(modules, &(elem(&1, 0) == :result)) == 19
    assert Enum.count(modules, &(elem(&1, 0) == :push)) == 3

    assert Trace.statuses() == ~w(accepted dispatched completed failed cancelled uncertain)
    assert Trace.terminal_status?("completed")
    refute Trace.terminal_status?("accepted")

    assert Update.event_types() == Seigyo.update_event_types()
    assert Update.terminal_event?("command_uncertain")
    refute Update.terminal_event?("command_accepted")

    assert Digest.sha256(true) != Digest.sha256(false)
  end
end
