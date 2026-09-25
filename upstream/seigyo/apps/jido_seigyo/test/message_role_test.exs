defmodule Jido.Seigyo.MessageRoleTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.{Catalog, SessionOpen, SessionOpened, Update}
  alias Jido.Seigyo.Client.Wire

  @session "ses_01994770-1234-7000-8000-000000000001"
  @workspace "ws_01994770-1234-7000-8000-000000000002"

  test "SEIGYO-MESSAGE-001: the catalog gives one role and direction to each Signal" do
    assert {:ok, %{role: :request, direction: :client_to_server}} =
             Catalog.message(SessionOpen.type())

    assert {:ok, %{role: :reply, direction: :server_to_client}} =
             Catalog.message(SessionOpened.type())

    assert {:ok, %{role: :event, authority: :saved}} = Catalog.message(Update.type())
    assert :error = Catalog.message("jido.internal.execute")
    assert :error = Catalog.message("jido.client.v2.session.open")
  end

  test "SEIGYO-MESSAGE-001: changing source cannot turn a Reply into a Request" do
    {:ok, reply} =
      SessionOpened.new(%{
        "version" => 1,
        "session_id" => @session,
        "workspace_id" => @workspace,
        "protocol_version" => 1,
        "protocol_profile" => "coding"
      })

    forged = %{reply | source: "/jido/code/client"}
    assert {:error, _} = Wire.encode_request(forged, SessionOpened)
  end

  test "SEIGYO-MESSAGE-001: changing source cannot turn a Request into a Reply" do
    {:ok, request} =
      SessionOpen.new(%{"version" => 1, "session_id" => @session, "workspace_id" => nil})

    {:ok, encoded} = Jido.Signal.serialize(%{request | source: "/jido/code/server"})
    assert {:error, _} = Wire.decode_result(Jason.decode!(encoded), SessionOpen)
  end
end
