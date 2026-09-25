defmodule Jido.Seigyo.Client.WireTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client
  alias Jido.Seigyo.Client.Wire

  alias Jido.Seigyo.{
    Error,
    Failure,
    ID,
    MemberAdd,
    MembershipUpdate,
    SessionOpen,
    SessionOpened
  }

  test "request encoding produces the strict client Signal envelope" do
    assert {:ok, signal} =
             SessionOpen.new(%{
               "version" => 1,
               "session_id" => ID.generate(:session),
               "workspace_id" => nil
             })

    assert {:ok, encoded} = Wire.encode_request(signal, SessionOpen)
    assert Enum.sort(Map.keys(encoded)) == ~w(data id source specversion type)
    assert encoded["source"] == "/jido/code/client"
    assert encoded["type"] == SessionOpen.type()
  end

  test "result decoding checks the server source and expected type" do
    assert {:ok, signal} =
             SessionOpened.new(%{
               "version" => 1,
               "session_id" => ID.generate(:session),
               "workspace_id" => ID.generate(:workspace),
               "protocol_version" => 1,
               "protocol_profile" => "coding"
             })

    encoded = encode(signal)
    assert {:ok, decoded} = Wire.decode_result(encoded, SessionOpened)
    assert decoded.data == signal.data

    assert {:error, %Client.Error{kind: :protocol, reason: :invalid_signal_envelope}} =
             encoded
             |> Map.put("source", "/untrusted/server")
             |> Wire.decode_result(SessionOpened)
  end

  test "failure decoding returns the stable Seigyo error" do
    assert {:ok, signal} = Failure.new(Error.to_map(Error.new("not_found", "session_id")))

    assert {:ok, %Error{code: "not_found", field: "session_id"}} =
             signal
             |> encode()
             |> Wire.decode_failure()
  end

  test "membership messages require the negotiated feature at both wire directions" do
    feature = "seigyo.membership/1"

    assert {:ok, request} =
             MemberAdd.new(%{
               "version" => 1,
               "mutation_id" => ID.generate(:mutation),
               "session_id" => ID.generate(:session),
               "actor_id" => ID.generate(:actor),
               "role" => "editor",
               "expected_revision" => 0
             })

    assert {:error, %Error{code: "invalid_field", field: "type"}} =
             Wire.encode_request(request, MemberAdd)

    assert {:ok, _encoded} = Wire.encode_request(request, MemberAdd, [feature])

    assert {:ok, update} =
             MembershipUpdate.new(%{
               "version" => 1,
               "session_id" => request.data["session_id"],
               "kind" => "event",
               "sequence" => 1,
               "event_type" => "member_added",
               "command_id" => nil,
               "payload" => %{
                 "mutation_id" => request.data["mutation_id"],
                 "previous_revision" => 0,
                 "member" => %{
                   "id" => ID.generate(:actor_instance),
                   "actor_id" => request.data["actor_id"],
                   "actor_kind" => "actor",
                   "display_name" => "Build actor",
                   "role" => "editor",
                   "status" => "active",
                   "revision" => 1
                 }
               }
             })

    assert {:error, %Client.Error{kind: :protocol}} =
             update |> encode() |> Wire.decode_result(MembershipUpdate)

    assert {:ok, decoded} =
             update |> encode() |> Wire.decode_result(MembershipUpdate, [feature])

    assert decoded.data["event_type"] == "member_added"
  end

  defp encode(signal) do
    {:ok, json} = Jido.Signal.serialize(signal)
    Jason.decode!(json)
  end
end
