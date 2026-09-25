defmodule Jido.Seigyo.Client.CanonicalValueTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Client

  @session "ses_01994770-1234-7000-8000-000000000001"
  @workspace "ws_01994770-1234-7000-8000-000000000002"

  test "SEIGYO-DEFINITION-003: client Session uses the complete closed payload contract" do
    data = %{
      "version" => 1,
      "session_id" => @session,
      "workspace_id" => @workspace,
      "protocol_version" => 1,
      "protocol_profile" => "coding"
    }

    assert {:ok, %Client.Session{id: @session}} = Client.Session.from_data(data)

    for invalid <- [
          Map.put(data, "extra", true),
          Map.delete(data, "version"),
          Map.put(data, "version", 2)
        ] do
      assert {:error, _} = Jido.Seigyo.SessionOpened.validate_data(invalid)
      assert {:error, _} = Client.Session.from_data(invalid)
    end
  end

  test "SEIGYO-DEFINITION-003: nested client values reject unknown keys and unsafe integers" do
    workspace = %{
      "id" => @workspace,
      "name" => "example",
      "file_path" => "/tmp/example",
      "runtime_path" => "/workspace",
      "ownership" => "managed",
      "mode" => "shared",
      "status" => "ready",
      "version" => 1
    }

    assert {:ok, _} = Client.Workspaces.from_data(%{"version" => 1, "workspaces" => [workspace]})

    for invalid <- [
          Map.put(workspace, "extra", true),
          Map.put(workspace, "version", 9_007_199_254_740_992)
        ] do
      data = %{"version" => 1, "workspaces" => [invalid]}
      assert {:error, _} = Jido.Seigyo.Workspaces.validate_data(data)
      assert {:error, _} = Client.Workspaces.from_data(data)
    end
  end
end
