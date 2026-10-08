defmodule DASP.Discovery.Manifest do
  @moduledoc """
  Validates a closed schema-resource manifest and its injected exact bytes.

  This module resolves references only against supplied manifest resources. It
  does not perform network, file, module, vocabulary, or format lookup. It does
  not compile or evaluate a discovered schema.
  """

  alias DASP.Discovery.{Control, ResourceVerifier, SchemaJSON}
  alias DASP.Signal.Validation
  import DASP.Error, only: [fail: 2]

  @standard_vocabularies ~w(
    https://json-schema.org/draft/2020-12/vocab/core
    https://json-schema.org/draft/2020-12/vocab/applicator
    https://json-schema.org/draft/2020-12/vocab/unevaluated
    https://json-schema.org/draft/2020-12/vocab/validation
    https://json-schema.org/draft/2020-12/vocab/meta-data
    https://json-schema.org/draft/2020-12/vocab/format-annotation
    https://json-schema.org/draft/2020-12/vocab/content
  )
  @dialect "https://json-schema.org/draft/2020-12/schema"
  @schema_map_keywords ~w($defs properties patternProperties dependentSchemas)
  @schema_array_keywords ~w(allOf anyOf oneOf prefixItems)
  @single_schema_keywords ~w(
    additionalProperties unevaluatedProperties propertyNames contains
    unevaluatedItems not if then else items contentSchema
  )

  @enforce_keys [:document, :descriptors, :supported_vocabularies, :max_schema_nodes]
  defstruct [
    :document,
    :descriptors,
    :supported_vocabularies,
    :max_schema_nodes,
    resources: %{},
    representations: %{},
    schema_nodes: 0
  ]

  @type t :: %__MODULE__{}

  @doc "Validates manifest shape, closure bounds, identities, and vocabularies."
  @spec validate(map(), keyword()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def validate(document, opts \\ []) do
    DASP.Wire.protect(fn ->
      with {:ok, parsed} <- Zoi.parse(Control.manifest_schema(), document, coerce: false),
           true <- parsed == document do
        limits = Keyword.get(opts, :limits, %{})
        max_schema_nodes = Keyword.get(opts, :max_schema_nodes, SchemaJSON.default_max_nodes())

        if not is_integer(max_schema_nodes) or max_schema_nodes < 1,
          do: fail(:invalid_request, "The schema node limit must be a positive integer.")

        supported =
          MapSet.new(@standard_vocabularies ++ Keyword.get(opts, :supported_vocabularies, []))

        resources = document["resources"]
        resource_ids = Enum.map(resources, & &1["resource"])
        schema_ids = resources |> Enum.map(& &1["schema_id"]) |> Enum.reject(&is_nil/1)

        ensure_unique!(resource_ids, "resource identity")
        ensure_unique!(schema_ids, "schema identity")

        Enum.each(resource_ids, fn identity ->
          if not ResourceVerifier.safe_identity?(identity),
            do: fail(:unsafe_identity, "Manifest contains an unsafe resource identity.")
        end)

        if Enum.any?(resources, &(&1["dialect"] != @dialect)),
          do: fail(:unsupported_contract, "Only JSON Schema 2020-12 resources are supported.")

        if document["input_root"] not in resource_ids or
             document["output_root"] not in resource_ids,
           do: fail(:unresolved_reference, "A schema root is outside the closed manifest.")

        vocabulary_ids = Enum.map(document["vocabularies"], & &1["uri"])
        ensure_unique!(vocabulary_ids, "vocabulary identity")
        ensure_vocabularies!(document["vocabularies"], supported)
        ensure_closure_limits!(resources, limits)

        %__MODULE__{
          document: document,
          descriptors: Map.new(resources, &{&1["resource"], &1}),
          supported_vocabularies: supported,
          max_schema_nodes: max_schema_nodes
        }
      else
        _ -> fail(:invalid_request, "Invalid discovery schema manifest.")
      end
    end)
  end

  @doc "Adds one complete exact resource representation supplied by a binding."
  @spec put_resource(t(), String.t(), binary()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def put_resource(%__MODULE__{} = manifest, identity, bytes) when is_binary(bytes) do
    DASP.Wire.protect(fn ->
      descriptor =
        Map.get(manifest.descriptors, identity) ||
          fail(:unresolved_reference, "Resource is not in the closed manifest.")

      if Map.has_key?(manifest.resources, identity),
        do: fail(:duplicate_resource, "Schema resource was supplied more than once.")

      case ResourceVerifier.verify(descriptor, [bytes]) do
        {:ok, _result} -> :ok
        {:error, error} -> raise error
      end

      remaining_nodes = manifest.max_schema_nodes - manifest.schema_nodes

      if remaining_nodes < 1,
        do: fail(:request_limit, "Schema closure exceeds the local node limit.")

      {value, nodes} =
        case SchemaJSON.decode_with_count(bytes, max_nodes: remaining_nodes) do
          {:ok, decoded, nodes} when is_map(decoded) or is_boolean(decoded) ->
            {decoded, nodes}

          {:ok, _decoded, _nodes} ->
            fail(:invalid_schema, "A JSON Schema root must be an object or boolean.")

          {:error, error} ->
            raise error
        end

      validate_root_id!(descriptor, value)
      validate_root_dialect!(descriptor, value)

      %{
        manifest
        | resources: Map.put(manifest.resources, identity, value),
          representations: Map.put(manifest.representations, identity, bytes),
          schema_nodes: manifest.schema_nodes + nodes
      }
    end)
  end

  def put_resource(%__MODULE__{}, _identity, _bytes),
    do: error(:invalid_schema, "Schema resource representation must be a binary.")

  @doc "Checks that all resources and all schema references form one closed set."
  @spec finish(t()) :: {:ok, map()} | {:error, DASP.Error.t()}
  def finish(%__MODULE__{} = manifest) do
    DASP.Wire.protect(fn ->
      if Enum.any?(manifest.descriptors, fn {identity, _} ->
           not Map.has_key?(manifest.resources, identity)
         end),
         do: fail(:unresolved_reference, "The schema resource closure is incomplete.")

      state = %{
        nodes: %{},
        anchors: MapSet.new(),
        references: [],
        vocabularies: []
      }

      state =
        Enum.reduce(manifest.resources, state, fn {resource, value}, acc ->
          descriptor = Map.fetch!(manifest.descriptors, resource)
          base = descriptor["schema_id"] || private_base(resource)
          walk(value, base, acc, true)
        end)

      ensure_vocabularies!(state.vocabularies, manifest.supported_vocabularies)
      Enum.each(state.references, &resolve_reference!(&1, state))

      %{
        input: Map.fetch!(manifest.resources, manifest.document["input_root"]),
        output: Map.fetch!(manifest.resources, manifest.document["output_root"]),
        resources: manifest.resources,
        input_bytes: Map.fetch!(manifest.representations, manifest.document["input_root"]),
        output_bytes: Map.fetch!(manifest.representations, manifest.document["output_root"]),
        resource_bytes: manifest.representations
      }
    end)
  end

  defp walk(value, base, state, root?) when is_map(value) do
    {base, state} = register_id(value, base, state, root?)
    state = register_anchor(value["$anchor"], base, state)
    state = register_anchor(value["$dynamicAnchor"], base, state)

    state =
      case value["$vocabulary"] do
        vocabularies when is_map(vocabularies) ->
          entries =
            Enum.map(vocabularies, fn {uri, required} ->
              if not Validation.uri?(uri) or not is_boolean(required),
                do: fail(:invalid_schema, "Schema has an invalid $vocabulary declaration.")

              %{"uri" => uri, "required" => required}
            end)

          %{state | vocabularies: entries ++ state.vocabularies}

        nil ->
          state

        _ ->
          fail(:invalid_schema, "Schema $vocabulary must be an object.")
      end

    state = register_reference(value["$ref"], base, state)
    state = register_reference(value["$dynamicRef"], base, state)

    state
    |> walk_schema_maps(value, base)
    |> walk_schema_arrays(value, base)
    |> walk_single_schemas(value, base)
  end

  defp walk(value, base, state, true) when is_boolean(value),
    do: put_node!(state, base, value)

  defp walk(_value, _base, state, _root?), do: state

  defp walk_schema_maps(state, schema, base) do
    Enum.reduce(@schema_map_keywords, state, fn keyword, acc ->
      case schema[keyword] do
        children when is_map(children) ->
          Enum.reduce(children, acc, fn {_name, child}, nested_acc ->
            walk(child, base, nested_acc, false)
          end)

        _ ->
          acc
      end
    end)
  end

  defp walk_schema_arrays(state, schema, base) do
    Enum.reduce(@schema_array_keywords, state, fn keyword, acc ->
      case schema[keyword] do
        children when is_list(children) ->
          Enum.reduce(children, acc, fn child, nested_acc ->
            walk(child, base, nested_acc, false)
          end)

        _ ->
          acc
      end
    end)
  end

  defp walk_single_schemas(state, schema, base) do
    Enum.reduce(@single_schema_keywords, state, fn keyword, acc ->
      walk(schema[keyword], base, acc, false)
    end)
  end

  defp register_id(value, current_base, state, root?) do
    case value["$id"] do
      nil ->
        if root?,
          do: {current_base, put_node!(state, current_base, value)},
          else: {current_base, state}

      id when is_binary(id) ->
        resolved = resolve_id!(current_base, id)
        {resolved, put_node!(state, resolved, value)}

      _ ->
        fail(:invalid_schema, "Schema $id must be a string.")
    end
  end

  defp put_node!(state, id, value) do
    if Map.has_key?(state.nodes, id),
      do: fail(:duplicate_schema_identity, "Schema closure contains a duplicate $id.")

    %{state | nodes: Map.put(state.nodes, id, value)}
  end

  defp register_anchor(nil, _base, state), do: state

  defp register_anchor(anchor, base, state) when is_binary(anchor) do
    if not Regex.match?(~r/\A[A-Za-z_][-A-Za-z0-9._]*\z/, anchor),
      do: fail(:invalid_schema, "Schema anchor has invalid syntax.")

    key = {base, anchor}

    if MapSet.member?(state.anchors, key),
      do: fail(:duplicate_schema_anchor, "Schema closure contains a duplicate anchor.")

    %{state | anchors: MapSet.put(state.anchors, key)}
  end

  defp register_anchor(_, _base, _state),
    do: fail(:invalid_schema, "Schema anchor must be a string.")

  defp register_reference(nil, _base, state), do: state

  defp register_reference(reference, base, state) when is_binary(reference),
    do: %{state | references: [{reference, base} | state.references]}

  defp register_reference(_, _base, _state),
    do: fail(:invalid_schema, "Schema reference must be a string.")

  defp resolve_reference!({reference, current_base}, state) do
    {base, fragment} = reference_target!(reference, current_base)
    target = Map.get(state.nodes, base)

    if is_nil(target),
      do: fail(:unresolved_reference, "Schema reference is outside the closed manifest.")

    case decode_fragment!(fragment) do
      nil ->
        :ok

      "" ->
        :ok

      "/" <> _ = pointer ->
        if not json_pointer?(target, pointer),
          do: fail(:unresolved_reference, "Schema JSON Pointer does not resolve.")

      anchor ->
        if not MapSet.member?(state.anchors, {base, anchor}),
          do: fail(:unresolved_reference, "Schema anchor does not resolve.")
    end
  end

  defp reference_target!("#" <> fragment, current_base), do: {current_base, fragment}

  defp reference_target!(reference, current_base) do
    resolved = resolve_uri!(current_base, reference, :reference)
    uri = URI.parse(resolved)
    fragment = uri.fragment
    base = uri |> Map.put(:fragment, nil) |> URI.to_string()

    if base == "", do: {current_base, fragment}, else: {base, fragment}
  end

  defp resolve_id!(base, id) do
    resolved = resolve_uri!(base, id, :id)

    if String.contains?(resolved, "#"),
      do: fail(:invalid_schema, "Schema $id must be an absolute URI without a fragment.")

    resolved
  end

  defp resolve_uri!(_base, value, _kind) when not is_binary(value),
    do: fail(:invalid_schema, "Schema URI reference must be a string.")

  defp resolve_uri!(base, value, kind) do
    cond do
      Validation.uri?(value) ->
        value

      String.starts_with?(value, "#") ->
        base <> value

      String.starts_with?(base, "urn:dasp:private-resource:") ->
        fail(:unresolved_reference, "Relative schema reference has no public base URI.")

      true ->
        resolved =
          try do
            base |> URI.merge(value) |> URI.to_string()
          rescue
            _ -> nil
          end

        if is_binary(resolved) and Validation.uri?(resolved) do
          resolved
        else
          code = if kind == :id, do: :invalid_schema, else: :unresolved_reference
          fail(code, "Relative schema URI cannot be resolved against its base.")
        end
    end
  end

  defp json_pointer?(value, pointer) do
    result =
      pointer
      |> String.replace_prefix("/", "")
      |> String.split("/", trim: false)
      |> Enum.reduce_while({:ok, value}, fn token, {:ok, current} ->
        case decode_pointer_token(token) do
          {:ok, token} -> pointer_step(current, token)
          :error -> {:halt, :error}
        end
      end)

    match?({:ok, _}, result)
  end

  defp pointer_step(map, token) when is_map(map) do
    case Map.fetch(map, token) do
      {:ok, child} -> {:cont, {:ok, child}}
      :error -> {:halt, :error}
    end
  end

  defp pointer_step(list, token) when is_list(list) do
    if Regex.match?(~r/\A(?:0|[1-9][0-9]*)\z/, token) do
      case Enum.fetch(list, String.to_integer(token)) do
        {:ok, child} -> {:cont, {:ok, child}}
        :error -> {:halt, :error}
      end
    else
      {:halt, :error}
    end
  end

  defp pointer_step(_value, _token), do: {:halt, :error}

  defp decode_fragment!(nil), do: nil

  defp decode_fragment!(fragment) do
    case percent_decode(fragment, []) do
      {:ok, decoded} when is_binary(decoded) ->
        if String.valid?(decoded),
          do: decoded,
          else: fail(:unresolved_reference, "Schema reference fragment is invalid.")

      :error ->
        fail(:unresolved_reference, "Schema reference fragment is invalid.")
    end
  end

  defp percent_decode("", acc), do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

  defp percent_decode(<<"%", high, low, rest::binary>>, acc) do
    with {:ok, high} <- hex_value(high),
         {:ok, low} <- hex_value(low) do
      percent_decode(rest, [<<high * 16 + low>> | acc])
    else
      :error -> :error
    end
  end

  defp percent_decode(<<"%", _rest::binary>>, _acc), do: :error
  defp percent_decode(<<byte, rest::binary>>, acc), do: percent_decode(rest, [<<byte>> | acc])

  defp hex_value(value) when value in ?0..?9, do: {:ok, value - ?0}
  defp hex_value(value) when value in ?A..?F, do: {:ok, value - ?A + 10}
  defp hex_value(value) when value in ?a..?f, do: {:ok, value - ?a + 10}
  defp hex_value(_value), do: :error

  defp decode_pointer_token(token), do: decode_pointer_token(token, [])

  defp decode_pointer_token("", acc),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

  defp decode_pointer_token(<<"~0", rest::binary>>, acc),
    do: decode_pointer_token(rest, ["~" | acc])

  defp decode_pointer_token(<<"~1", rest::binary>>, acc),
    do: decode_pointer_token(rest, ["/" | acc])

  defp decode_pointer_token(<<"~", _rest::binary>>, _acc), do: :error

  defp decode_pointer_token(<<byte, rest::binary>>, acc),
    do: decode_pointer_token(rest, [<<byte>> | acc])

  defp validate_root_id!(%{"schema_id" => expected}, %{"$id" => actual})
       when is_binary(expected) and expected != actual,
       do: fail(:contract_violation, "Resource root $id differs from its descriptor schema_id.")

  defp validate_root_id!(_, _), do: :ok

  defp validate_root_dialect!(%{"dialect" => expected}, %{"$schema" => actual})
       when is_binary(actual) and expected != actual,
       do: fail(:contract_violation, "Resource root $schema differs from its descriptor dialect.")

  defp validate_root_dialect!(_, _), do: :ok

  defp ensure_unique!(values, name) do
    if length(values) != length(Enum.uniq(values)),
      do: fail(:invalid_request, "Manifest contains a duplicate #{name}.")
  end

  defp ensure_vocabularies!(vocabularies, supported) do
    Enum.each(vocabularies, fn
      %{"uri" => uri, "required" => true} ->
        if not MapSet.member?(supported, uri),
          do: fail(:unsupported_vocabulary, "Schema closure requires an unsupported vocabulary.")

      _ ->
        :ok
    end)
  end

  defp ensure_closure_limits!(resources, limits) do
    if is_integer(limits["closure_resources"]) and
         length(resources) > limits["closure_resources"],
       do: fail(:request_limit, "Schema closure exceeds the selected resource limit.")

    bytes = Enum.reduce(resources, 0, &(&1["byte_length"] + &2))

    if is_integer(limits["closure_bytes"]) and bytes > limits["closure_bytes"],
      do: fail(:request_limit, "Schema closure exceeds the selected byte limit.")

    if is_integer(limits["resource_bytes"]) and
         Enum.any?(resources, &(&1["byte_length"] > limits["resource_bytes"])),
       do: fail(:request_limit, "Schema resource exceeds the selected byte limit.")
  end

  defp private_base(resource),
    do: "urn:dasp:private-resource:" <> Base.url_encode64(resource, padding: false)

  defp error(code, message), do: {:error, %DASP.Error{code: code, message: message}}
end
