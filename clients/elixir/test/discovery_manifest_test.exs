defmodule DASP.Discovery.ManifestTest do
  use ExUnit.Case, async: true

  alias DASP.Discovery.Manifest

  @dialect "https://json-schema.org/draft/2020-12/schema"

  test "keeps annotations and unknown keywords inert and preserves exact bytes" do
    bytes =
      ~S({"$id":"urn:example:annotations","type":"object","default":{"$ref":"urn:missing:default"},"examples":[{"$dynamicRef":"urn:missing:example"}],"x-note":{"$id":"urn:missing:id","$ref":"urn:missing:annotation"},"const":{"$vocabulary":{"urn:missing:vocabulary":true}},"multipleOf":0.01})

    resources = [{descriptor("resource:annotations", "urn:example:annotations", bytes), bytes}]
    manifest = loaded_manifest(resources, "resource:annotations", "resource:annotations")

    assert {:ok, closure} = Manifest.finish(manifest)
    assert closure.input["default"]["$ref"] == "urn:missing:default"
    assert closure.input_bytes == bytes
    assert closure.output_bytes == bytes
    assert closure.resource_bytes["resource:annotations"] == bytes
  end

  test "registers true and false resource roots as reference targets" do
    root =
      ~S({"$id":"urn:example:boolean-user","allOf":[{"$ref":"urn:example:true-root"},{"$ref":"urn:example:false-root"}]})

    true_root = "true"
    false_root = "false"

    resources = [
      {descriptor("resource:boolean-user", "urn:example:boolean-user", root), root},
      {descriptor("resource:true-root", "urn:example:true-root", true_root), true_root},
      {descriptor("resource:false-root", "urn:example:false-root", false_root), false_root}
    ]

    manifest = loaded_manifest(resources, "resource:boolean-user", "resource:false-root")

    assert {:ok, closure} = Manifest.finish(manifest)
    assert closure.output == false
    assert closure.output_bytes == false_root
  end

  test "decodes the complete URI fragment before JSON Pointer tokens" do
    bytes =
      ~S({"$id":"urn:example:pointer","$defs":{"plain":true,"a/b":true,"til~de":true},"allOf":[{"$ref":"#%2F%24defs%2Fplain"},{"$ref":"#%2F%24defs%2Fa~1b"},{"$ref":"#%2F%24defs%2Ftil~0de"}]})

    resources = [{descriptor("resource:pointer", "urn:example:pointer", bytes), bytes}]
    manifest = loaded_manifest(resources, "resource:pointer", "resource:pointer")

    assert {:ok, _closure} = Manifest.finish(manifest)

    invalid = ~S({"$id":"urn:example:invalid-fragment","$ref":"#%2G"})

    invalid_resources = [
      {descriptor("resource:invalid-fragment", "urn:example:invalid-fragment", invalid), invalid}
    ]

    invalid_manifest =
      loaded_manifest(
        invalid_resources,
        "resource:invalid-fragment",
        "resource:invalid-fragment"
      )

    assert {:error, %DASP.Error{code: :unresolved_reference}} =
             Manifest.finish(invalid_manifest)
  end

  test "rejects a schema closure that exceeds the local node budget" do
    numbers = Enum.join(List.duplicate("0", 20), ",")
    bytes = ~s({"$id":"urn:example:node-budget","x-values":[#{numbers}]})
    descriptor = descriptor("resource:node-budget", "urn:example:node-budget", bytes)
    document = manifest_document([descriptor], "resource:node-budget", "resource:node-budget")

    assert {:ok, manifest} = Manifest.validate(document, max_schema_nodes: 10)

    assert {:error, %DASP.Error{code: :request_limit}} =
             Manifest.put_resource(manifest, "resource:node-budget", bytes)
  end

  defp loaded_manifest(resources, input_root, output_root) do
    descriptors = Enum.map(resources, &elem(&1, 0))
    document = manifest_document(descriptors, input_root, output_root)
    assert {:ok, manifest} = Manifest.validate(document)

    Enum.reduce(resources, manifest, fn {descriptor, bytes}, current ->
      assert {:ok, next} = Manifest.put_resource(current, descriptor["resource"], bytes)
      next
    end)
  end

  defp manifest_document(resources, input_root, output_root) do
    %{
      "input_root" => input_root,
      "output_root" => output_root,
      "resources" => resources,
      "vocabularies" => [],
      "closed" => true
    }
  end

  defp descriptor(resource, schema_id, bytes) do
    %{
      "resource" => resource,
      "media_type" => "application/schema+json",
      "dialect" => @dialect,
      "schema_id" => schema_id,
      "byte_length" => byte_size(bytes)
    }
  end
end
