defmodule Jido.Seigyo.CatalogTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.{Catalog, Error, Release}

  test "SEIGYO-DEFINITION-001: each operation has one complete public definition" do
    for operation <- Catalog.operations() do
      assert {:ok, ^operation} = Catalog.operation(operation.name)
      assert operation.role == :request
      assert operation.direction == :client_to_server
      assert operation.profile == "coding"
      assert operation.retry in [:read, :session, :command, :mutation]
      assert operation.requirements != []
      assert operation.failures == Error.codes()

      if operation.request do
        assert operation.arguments == nil
        assert operation.args_schema == nil
      else
        assert is_list(operation.arguments)
        assert operation.args_schema["additionalProperties"] == false
        assert Enum.sort(operation.arguments) == operation.args_schema["required"]
      end

      released = Enum.find(Release.manifest()["operations"], &(&1["name"] == operation.name))
      assert released["args_schema"] == operation.args_schema
      assert released["failure_delivery"] == operation.failure_delivery
      assert released["requirements"] == operation.requirements
    end

    assert :error = Catalog.operation("internal.agent.signal")
    assert :error = Catalog.operation(nil)
  end

  test "SEIGYO-DEFINITION-002: event authority is separate from a reply and runtime diagnostics" do
    assert Catalog.events() == [
             %{name: "update", signal: Jido.Seigyo.Update, authority: :saved},
             %{name: "progress", signal: Jido.Seigyo.Progress, authority: :transient},
             %{name: "resync_required", signal: Jido.Seigyo.ResyncRequired, authority: :delivery}
           ]

    for control <- Catalog.controls() do
      assert control.role == :request
      assert control.direction == :client_to_server
      assert control.retry == :connection
      assert is_map(control.args_schema)
      assert control.requirements != []
    end
  end
end
