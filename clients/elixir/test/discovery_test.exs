defmodule DASP.DiscoveryTest do
  use ExUnit.Case, async: true

  alias DASP.Discovery.{Enumeration, Manifest, ResourceVerifier}

  @root Path.expand("../../..", __DIR__)
  @contract "https://dasp-protocol.github.io/dasp/contracts/capability-discovery"
  @custom_vocabulary "urn:example:dasp:vocabulary:agent-handoff"

  test "validates the normative control examples and rejects unknown and duplicate fields" do
    documents = example_documents()
    assert Enum.all?(documents, &match?({:ok, _}, DASP.Discovery.validate(&1)))

    invalid = documents |> hd() |> Map.put("authorization", "not part of discovery")
    assert {:error, %DASP.Error{code: :invalid_request}} = DASP.Discovery.validate(invalid)

    duplicate =
      ~s({"contract":"#{@contract}","version":"draft-01","operation":"capabilities.snapshot.release","kind":"request","snapshot":"one","snapshot":"two"})

    assert {:error, %DASP.Error{code: :invalid_json}} = DASP.Discovery.decode(duplicate)
  end

  test "uses the same closed failure shapes in schema and validation" do
    limit = %{"name" => "live_snapshots", "maximum" => 2, "actual" => 2}
    limited = failure_document("snapshot_capacity", %{"limit" => limit})
    plain = failure_document("stale_snapshot")

    for document <- [limited, plain] do
      assert {:ok, ^document} = Zoi.parse(DASP.Discovery.schema(), document, coerce: false)
      assert {:ok, ^document} = DASP.Discovery.validate(document)
    end

    forbidden = failure_document("invalid_request", %{"limit" => limit})
    assert {:error, _errors} = Zoi.parse(DASP.Discovery.schema(), forbidden, coerce: false)
    assert {:error, %DASP.Error{code: :invalid_request}} = DASP.Discovery.validate(forbidden)
  end

  test "reads the shared 1,000-command fixture with a counting carrier" do
    fixture = fixture()
    limits = scale_limits(fixture)
    pages = scale_pages(fixture, limits["page_items"])
    {:ok, counter} = Agent.start_link(fn -> %{calls: 0, summaries: 0} end)

    carrier = fn request ->
      index =
        Agent.get_and_update(counter, fn counts ->
          {counts.calls, %{counts | calls: counts.calls + 1}}
        end)

      page = Enum.fetch!(pages, index)

      if index > 0 do
        assert request["continuation"] == Enum.fetch!(pages, index - 1)["continuation"]
      end

      {:ok, page}
    end

    on_summary = fn _summary ->
      Agent.update(counter, &Map.update!(&1, :summaries, fn value -> value + 1 end))
      :ok
    end

    assert {:ok, state} =
             DASP.Discovery.enumerate(start_request(fixture, limits), carrier,
               on_summary: on_summary
             )

    assert state.complete
    assert state.page_count == fixture["paging"]["item_bound"]["expected_pages"]
    assert state.item_count == fixture["catalog"]["summary_count"]
    assert state.received_control_bytes > 0
    assert state.max_pages == limits["view_items"] + 1
    assert state.max_items == limits["view_items"]
    assert state.max_control_bytes == limits["control_bytes"] * state.max_pages
    assert MapSet.size(state.capabilities) == 1000
    assert Agent.get(counter, & &1) == %{calls: 10, summaries: 1000}
    assert {:error, %DASP.Error{code: :invalid_request}} = Enumeration.summaries(state)
  end

  test "preserves list failures and binds the first reply to the requested actor" do
    fixture = fixture()
    request = start_request(fixture, start_limits())
    limit = %{"name" => "live_snapshots", "maximum" => 2, "actual" => 2}
    failure = failure_document("snapshot_capacity", %{"limit" => limit})

    assert {:error, ^failure} =
             DASP.Discovery.enumerate(request, fn _request -> {:ok, failure} end)

    [_, first | _] = example_documents()
    wrong_actor = Map.put(first, "actor", "actor:other")

    assert {:error, %DASP.Error{code: :contract_violation}} =
             DASP.Discovery.enumerate(request, fn _request -> {:ok, wrong_actor} end,
               on_page: fn _page -> send(self(), :unexpected_page) end
             )

    refute_received :unexpected_page
  end

  test "enforces local cumulative enumeration options before callbacks" do
    [_, first, _, terminal | _] = example_documents()
    first_bytes = byte_size(DASP.JSON.encode!(first))
    terminal_bytes = byte_size(DASP.JSON.encode!(terminal))

    for options <- [
          [max_pages: 1],
          [max_items: 1],
          [max_control_bytes: first_bytes + terminal_bytes - 1]
        ] do
      parent = self()

      on_page = fn _page ->
        send(parent, :accepted_page)
        :ok
      end

      assert {:ok, state} = Enumeration.new(Keyword.put(options, :on_page, on_page))
      assert {:ok, state} = Enumeration.push(state, first)
      assert_received :accepted_page
      assert {:error, %DASP.Error{code: :request_limit}} = Enumeration.push(state, terminal)
      refute_received :accepted_page
    end
  end

  test "optionally accumulates summaries after incremental validation" do
    [_, first, _, terminal | _] = example_documents()
    assert {:ok, state} = Enumeration.new(accumulate: true)
    assert {:ok, state} = Enumeration.push(state, first)
    assert {:ok, state} = Enumeration.push(state, terminal)
    assert {:ok, summaries} = Enumeration.summaries(state)

    assert Enum.map(summaries, &get_in(&1, ["capability", "command"])) == [
             "agent.ask",
             "agent.delegate"
           ]
  end

  test "applies the control-byte limit to the received page bytes" do
    [_, first | _] = example_documents()
    compact = DASP.JSON.encode!(first)
    limits = Map.put(start_limits(), "control_bytes", byte_size(compact))
    assert {:ok, state} = Enumeration.new(limits: limits)
    assert {:ok, _state} = Enumeration.push(state, compact)

    assert {:error, %DASP.Error{code: :contract_violation}} =
             Enumeration.push(state, " " <> compact)
  end

  test "rejects mixed contexts, duplicate identities, ordering errors, and token loops" do
    [_, first, _, terminal | _] = example_documents()
    assert {:ok, initial} = Enumeration.new()
    assert {:ok, state} = Enumeration.push(initial, first)

    mixed_profile = put_in(terminal, ["profile", "version"], "2.0.0")

    assert {:error, %DASP.Error{code: :contract_violation}} =
             Enumeration.push(state, mixed_profile)

    mixed_snapshot = Map.put(terminal, "snapshot", "snapshot:other")

    assert {:error, %DASP.Error{code: :contract_violation}} =
             Enumeration.push(state, mixed_snapshot)

    duplicate = put_in(terminal, ["summaries"], first["summaries"])
    assert {:error, %DASP.Error{code: :contract_violation}} = Enumeration.push(state, duplicate)

    unordered =
      put_in(terminal, ["summaries", Access.at(0), "capability", "command"], "agent.aaa")

    assert {:error, %DASP.Error{code: :contract_violation}} = Enumeration.push(state, unordered)

    looping =
      terminal
      |> Map.put("page", "page:agent-42:1:2-loop")
      |> Map.put("complete", false)
      |> Map.put("continuation", first["continuation"])

    assert {:error, %DASP.Error{code: :contract_violation}} = Enumeration.push(state, looping)

    assert {:ok, bounded_view} = Enumeration.new(limits: %{start_limits() | "view_items" => 1})
    assert {:ok, bounded_view} = Enumeration.push(bounded_view, first)

    assert {:error, %DASP.Error{code: :contract_violation}} =
             Enumeration.push(bounded_view, terminal)
  end

  test "validates an atomic detail reply and its closed manifests" do
    documents = example_documents()
    first = Enum.at(documents, 1)
    terminal = Enum.at(documents, 3)
    request = Enum.at(documents, 4)
    reply = Enum.at(documents, 5)

    assert {:ok, state} = Enumeration.new()
    assert {:ok, state} = Enumeration.push(state, first)
    assert {:ok, state} = Enumeration.push(state, terminal)

    options = [supported_vocabularies: [@custom_vocabulary]]
    assert {:ok, details} = DASP.Discovery.validate_details(request, reply, state, options)
    assert length(details) == 2

    reversed = Map.update!(reply, "details", &Enum.reverse/1)

    assert {:error, %DASP.Error{code: :contract_violation}} =
             DASP.Discovery.validate_details(request, reversed, state, options)

    partial = Map.update!(reply, "details", &Enum.take(&1, 1))

    assert {:error, %DASP.Error{code: :contract_violation}} =
             DASP.Discovery.validate_details(request, partial, state, options)
  end

  test "enforces selected detail control and opaque byte limits" do
    documents = example_documents()
    first = Enum.at(documents, 1)
    terminal = Enum.at(documents, 3)
    request = Enum.at(documents, 4)
    reply = Enum.at(documents, 5)
    assert {:ok, state} = Enumeration.new()
    assert {:ok, state} = Enumeration.push(state, first)
    assert {:ok, state} = Enumeration.push(state, terminal)

    request_bytes = DASP.JSON.encode!(request)
    reply_bytes = DASP.JSON.encode!(reply)
    request_limits = %{start_limits() | "control_bytes" => byte_size(request_bytes) - 1}

    assert {:error, %DASP.Error{code: :request_limit}} =
             DASP.Discovery.validate_details(request, reply, state,
               limits: request_limits,
               supported_vocabularies: [@custom_vocabulary]
             )

    reply_limits = %{start_limits() | "control_bytes" => byte_size(reply_bytes) - 1}

    assert {:error, %DASP.Error{code: :contract_violation}} =
             DASP.Discovery.validate_details(request_bytes, reply_bytes, state,
               limits: reply_limits,
               supported_vocabularies: [@custom_vocabulary]
             )

    maximum = byte_size(request["snapshot"])
    long_resource = String.duplicate("r", maximum + 1)

    oversized_reply =
      reply
      |> put_in(["details", Access.at(0), "schemas", "input_root"], long_resource)
      |> put_in(
        ["details", Access.at(0), "schemas", "resources", Access.at(0), "resource"],
        long_resource
      )

    opaque_limits = %{start_limits() | "opaque_bytes" => maximum}

    assert {:error,
            %DASP.Error{
              code: :contract_violation,
              message: "Discovery opaque value exceeds its byte limit."
            }} =
             DASP.Discovery.validate_details(request, oversized_reply, state,
               limits: opaque_limits,
               supported_vocabularies: [@custom_vocabulary]
             )
  end

  test "accepts a complete exact-byte schema closure without evaluating it" do
    manifest_document = example_manifest()

    assert {:ok, manifest} =
             Manifest.validate(manifest_document,
               supported_vocabularies: [@custom_vocabulary],
               limits: start_limits()
             )

    manifest =
      Enum.reduce(manifest_document["resources"], manifest, fn descriptor, current ->
        bytes = resource_bytes(descriptor["resource"])
        assert {:ok, next} = Manifest.put_resource(current, descriptor["resource"], bytes)
        next
      end)

    assert {:ok, closure} = Manifest.finish(manifest)
    assert is_map(closure.input)
    assert closure.output == true
  end

  test "rejects incomplete references, duplicate keys, ids, anchors, and required vocabularies" do
    assert {:error, %DASP.Error{code: :unsupported_vocabulary}} =
             Manifest.validate(example_manifest())

    unresolved = schema_closure(~s({"$id":"urn:example:root","$ref":"urn:example:missing"}))
    assert {:error, %DASP.Error{code: :unresolved_reference}} = finish_single(unresolved)

    duplicate_key = schema_closure(~s({"$id":"urn:example:root","type":"string","type":"number"}))
    assert {:error, %DASP.Error{code: :duplicate_json_key}} = put_single(duplicate_key)

    duplicate_id =
      schema_closure(
        ~s({"$id":"urn:example:root","$defs":{"a":{"$id":"urn:example:same"},"b":{"$id":"urn:example:same"}}})
      )

    assert {:error, %DASP.Error{code: :duplicate_schema_identity}} = finish_single(duplicate_id)

    duplicate_anchor =
      schema_closure(
        ~s({"$id":"urn:example:root","$defs":{"a":{"$anchor":"same"},"b":{"$dynamicAnchor":"same"}}})
      )

    assert {:error, %DASP.Error{code: :duplicate_schema_anchor}} = finish_single(duplicate_anchor)
  end

  test "verifies exact resource bytes incrementally and rejects bad metadata" do
    fixture = fixture()
    stream = fixture["resource_stream"]
    bytes = File.read!(Path.join(@root, stream["trusted_fixture_file"]))
    descriptor = descriptor("resource:agent-ask-input", bytes, stream["digest"]["value"])
    chunks = split_chunks(bytes, stream["chunk_bytes"])

    assert {:ok, result} = ResourceVerifier.verify(descriptor, chunks)
    assert result["byte_length"] == stream["byte_length"]
    assert result["sha256"] == stream["digest"]["value"]

    bad_length = Map.put(descriptor, "byte_length", byte_size(bytes) + 1)

    assert {:error, %DASP.Error{code: :length_mismatch}} =
             ResourceVerifier.verify(bad_length, chunks)

    bad_digest = put_in(descriptor, ["digest", "value"], String.duplicate("0", 64))

    assert {:error, %DASP.Error{code: :digest_mismatch}} =
             ResourceVerifier.verify(bad_digest, chunks)

    unsupported = put_in(descriptor, ["digest", "algorithm"], "sha-512")
    assert {:error, %DASP.Error{code: :unsupported_digest}} = ResourceVerifier.new(unsupported)

    for identity <- fixture["unsafe_resource_identities"] do
      assert {:error, %DASP.Error{code: :unsafe_identity}} =
               descriptor(identity, bytes, stream["digest"]["value"])
               |> ResourceVerifier.new()
    end
  end

  test "keeps capability discovery and profile interaction out of the 14 core Signal types" do
    types = ~w(
      dasp.v1.session.open dasp.v1.session.opened dasp.v1.command dasp.v1.receipt
      dasp.v1.update dasp.v1.progress dasp.v1.view.read dasp.v1.view
      dasp.v1.updates.read dasp.v1.updates dasp.v1.outcome.read dasp.v1.outcome
      dasp.v1.resync.required dasp.v1.failure
    )

    assert length(types) == 14
    assert Enum.all?(types, &(DASP.Signal.module(&1) != nil))
    assert DASP.Signal.module("capabilities.list") == nil
    assert DASP.Signal.module("dasp.v1.thread") == nil
    assert DASP.Signal.module("dasp.v1.turn") == nil
  end

  defp example_documents do
    Path.join(@root, "specification/draft-01/examples/capability-discovery.json")
    |> File.read!()
    |> DASP.JSON.decode!()
  end

  defp fixture do
    Path.join(@root, "conformance/fixtures/capability-discovery.json")
    |> File.read!()
    |> DASP.JSON.decode!()
  end

  defp start_request(fixture, limits) do
    {:ok, request} =
      DASP.Discovery.new("capabilities.list", "request", %{
        "start" => fixture["idempotency"]["start"],
        "actor" => fixture["actor"],
        "limits" => limits
      })

    request
  end

  defp failure_document(code, fields \\ %{}) do
    Map.merge(fields, %{
      "contract" => @contract,
      "version" => "draft-01",
      "operation" => "capabilities.list",
      "kind" => "failure",
      "code" => code
    })
  end

  defp scale_limits(fixture) do
    start_limits()
    |> Map.put("page_items", fixture["paging"]["item_bound"]["page_items"])
    |> Map.put("view_items", fixture["paging"]["item_bound"]["view_items"])
    |> Map.put("control_bytes", fixture["paging"]["item_bound"]["control_bytes"])
  end

  defp start_limits do
    %{
      "page_items" => 100,
      "view_items" => 1000,
      "detail_items" => 4,
      "control_bytes" => 1_048_576,
      "presentation_bytes" => 8192,
      "resource_bytes" => 1_048_576,
      "closure_resources" => 16,
      "closure_bytes" => 4_194_304,
      "opaque_bytes" => 4096,
      "live_snapshots" => 2,
      "snapshot_retention_ms" => 300_000
    }
  end

  defp scale_pages(fixture, page_items) do
    count = fixture["catalog"]["summary_count"]
    profile = fixture["profile"]
    chunks = Enum.chunk_every(0..(count - 1), page_items)

    chunks
    |> Enum.with_index()
    |> Enum.map(fn {indices, page_index} ->
      terminal? = page_index == length(chunks) - 1

      fields = %{
        "actor" => fixture["actor"],
        "profile" => profile,
        "snapshot" => fixture["catalog"]["snapshot"],
        "resolved_view" => fixture["catalog"]["resolved_view"],
        "page" => "page:scale:#{page_index}",
        "summaries" => Enum.map(indices, &scale_summary(&1, profile, fixture)),
        "complete" => terminal?
      }

      fields =
        if terminal?,
          do: fields,
          else: Map.put(fields, "continuation", "next:scale:#{page_index + 1}")

      {:ok, page} = DASP.Discovery.new("capabilities.list", "reply", fields)
      page
    end)
  end

  defp scale_summary(index, profile, fixture) do
    command = fixture["catalog"]["command_prefix"] <> String.pad_leading("#{index}", 4, "0")

    %{
      "capability" => %{
        "profile_uri" => profile["uri"],
        "profile_version" => profile["version"],
        "command" => command
      },
      "profile_requirement" => if(rem(index, 10) == 0, do: "optional", else: "required")
    }
  end

  defp example_manifest do
    example_documents()
    |> Enum.find(&(&1["operation"] == "capabilities.get" and &1["kind"] == "reply"))
    |> get_in(["details", Access.at(0), "schemas"])
  end

  defp resource_bytes("resource:agent-ask-input"), do: schema_file("agent-ask-input.schema.json")
  defp resource_bytes("resource:allow-any"), do: schema_file("allow-any.schema.json")
  defp resource_bytes("resource:shared-context"), do: schema_file("shared-context.schema.json")

  defp schema_file(name) do
    @root
    |> Path.join("specification/draft-01/examples/capability-schemas")
    |> Path.join(name)
    |> File.read!()
  end

  defp schema_closure(bytes) do
    digest = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    {%{
       "input_root" => "resource:test",
       "output_root" => "resource:test",
       "resources" => [descriptor("resource:test", bytes, digest, "urn:example:root")],
       "vocabularies" => [],
       "closed" => true
     }, bytes}
  end

  defp put_single({document, bytes}) do
    descriptor = hd(document["resources"])
    {:ok, manifest} = Manifest.validate(document)
    Manifest.put_resource(manifest, descriptor["resource"], bytes)
  end

  defp finish_single({document, bytes}) do
    descriptor = hd(document["resources"])
    {:ok, manifest} = Manifest.validate(document)

    with {:ok, manifest} <- Manifest.put_resource(manifest, descriptor["resource"], bytes) do
      Manifest.finish(manifest)
    end
  end

  defp descriptor(resource, bytes, digest, schema_id \\ nil) do
    descriptor = %{
      "resource" => resource,
      "media_type" => "application/schema+json",
      "dialect" => "https://json-schema.org/draft/2020-12/schema",
      "byte_length" => byte_size(bytes),
      "digest" => %{
        "algorithm" => "sha-256",
        "media_type" => "application/schema+json",
        "value" => digest
      }
    }

    if schema_id, do: Map.put(descriptor, "schema_id", schema_id), else: descriptor
  end

  defp split_chunks(bytes, sizes) do
    {chunks, ""} =
      Enum.map_reduce(sizes, bytes, fn size, rest ->
        <<chunk::binary-size(^size), tail::binary>> = rest
        {chunk, tail}
      end)

    chunks
  end
end
