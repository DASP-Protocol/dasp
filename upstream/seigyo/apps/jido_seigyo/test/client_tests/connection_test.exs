defmodule Jido.Seigyo.Client.ConnectionTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client.Connection

  test "an HTTP endpoint becomes an encoded WebSocket endpoint" do
    assert {:ok, url} =
             Connection.websocket_url("https://code.example.test/base/", "token value")

    uri = URI.parse(url)
    assert uri.scheme == "wss"
    assert uri.host == "code.example.test"
    assert uri.path == "/base/client/socket/websocket"
    assert URI.decode_query(uri.query) == %{"token" => "token value", "vsn" => "2.0.0"}
  end

  test "an endpoint with a query is rejected" do
    assert {:error, :invalid_url} =
             Connection.websocket_url("ws://localhost:4000?unexpected=true", "token")
  end

  test "an endpoint with URL credentials is rejected" do
    assert {:error, :invalid_url} =
             Connection.websocket_url("wss://user:secret@code.example.test", "token")
  end
end
