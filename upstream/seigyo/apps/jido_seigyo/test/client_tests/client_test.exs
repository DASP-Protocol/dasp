defmodule Jido.Seigyo.ClientTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client

  test "connection options fail before network use" do
    Process.flag(:trap_exit, true)

    assert {:error,
            %Client.Error{
              kind: :connection,
              reason: {:invalid_option, :connect_timeout}
            }} =
             Client.start_link(
               url: "ws://127.0.0.1:1",
               token: "token",
               connect_timeout: 0
             )
  end
end
