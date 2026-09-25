defmodule Jido.Seigyo.BundleTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.Bundle

  test "SEIGYO-RELEASE-001: exact bytes and names determine one contract identity" do
    files = %{"rules.md" => "Rule one.\n", "schemas.json" => "{}\n"}
    descriptor = Bundle.descriptor(files)

    assert descriptor == Bundle.descriptor(Map.new(Enum.reverse(Map.to_list(files))))
    assert descriptor["protocol"] == 1
    assert descriptor["profile"] == "coding"
    assert descriptor["binding"] == "phoenix-channel-websocket"
    assert descriptor["algorithm"] == "seigyo-sha256-file-index-v1"
    assert Enum.map(descriptor["files"], & &1["path"]) == ~w(rules.md schemas.json)
    assert Enum.map(descriptor["files"], & &1["bytes"]) == [10, 3]
    assert :ok = Bundle.verify(descriptor, files)

    for changed <- [
          Map.put(files, "rules.md", "Rule two.\n"),
          Map.put(files, "rules.md", "Rule one.\r\n"),
          Map.delete(files, "rules.md"),
          Map.put(files, "extra.md", ""),
          %{"renamed.md" => "Rule one.\n", "schemas.json" => "{}\n"}
        ] do
      assert {:error, :contract_mismatch} = Bundle.verify(descriptor, changed)
    end

    assert {:error, :contract_mismatch} =
             Bundle.verify(Map.put(descriptor, "digest", String.duplicate("0", 64)), files)
  end

  test "SEIGYO-RELEASE-001: the package carries the complete frozen baseline" do
    files = Bundle.files()
    descriptor = Bundle.contract()

    assert :ok = Bundle.verify(descriptor, files)
    assert Map.has_key?(files, "schemas.json")
    assert Map.has_key?(files, "docs/seigyo/release-policy.md")
    refute Map.has_key?(files, "contract.json")
    refute Map.has_key?(files, "provenance.json")

    schemas = JSON.decode!(files["schemas.json"])
    assert schemas == Jido.Seigyo.Release.schemas()
  end

  test "SEIGYO-RELEASE-002: independent positive and negative data vectors stay valid" do
    vectors = Bundle.files() |> Map.fetch!("vectors.json") |> JSON.decode!()

    for vector <- vectors do
      assert {:ok, module} = Jido.Seigyo.Catalog.signal_module(vector["type"])
      result = module.validate_data(vector["data"])
      assert elem(result, 0) == :ok == vector["valid"], vector["name"]
    end
  end
end
