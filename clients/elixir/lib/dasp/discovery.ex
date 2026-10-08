defmodule DASP.Discovery do
  @moduledoc """
  Protocol-neutral helpers for the optional capability-discovery contract.

  Discovery documents are setup control data. They are not DASP Signals and
  they do not authorize a command. A binding adapter owns authentication,
  framing, correlation, and transport. JSON Schema resources remain exact
  byte strings outside DASP portable event JSON.
  """

  alias DASP.Discovery.{Control, Enumeration, Manifest}
  import DASP.Error, only: [fail: 2]

  @type document :: %{required(String.t()) => term()}

  @doc "Returns the closed Zoi schema for discovery control documents."
  @spec schema() :: Zoi.schema()
  def schema, do: Control.schema()

  @doc "Builds and validates one discovery control document."
  @spec new(String.t(), String.t(), map()) :: {:ok, document()} | {:error, DASP.Error.t()}
  def new(operation, kind, fields)
      when is_binary(operation) and is_binary(kind) and is_map(fields) and not is_struct(fields) do
    fields
    |> Map.merge(%{
      "contract" => Control.contract(),
      "version" => Control.version(),
      "operation" => operation,
      "kind" => kind
    })
    |> validate()
  end

  def new(_, _, _), do: error(:invalid_request, "Discovery fields must be a JSON object.")

  @doc "Validates one decoded discovery control document without coercion."
  @spec validate(term()) :: {:ok, document()} | {:error, DASP.Error.t()}
  def validate(document) do
    DASP.Wire.protect(fn ->
      with {:ok, parsed} <- Zoi.parse(schema(), document, coerce: false),
           true <- parsed == document do
        DASP.JSON.encode!(document)
        document
      else
        _ -> fail(:invalid_request, "Invalid capability-discovery control document.")
      end
    end)
  end

  @doc "Decodes UTF-8 JSON and rejects duplicate keys before control validation."
  @spec decode(binary()) :: {:ok, document()} | {:error, DASP.Error.t()}
  def decode(bytes) when is_binary(bytes) do
    DASP.Wire.protect(fn ->
      case validate(DASP.JSON.decode!(bytes)) do
        {:ok, document} -> document
        {:error, error} -> raise error
      end
    end)
  end

  def decode(_), do: error(:invalid_request, "Discovery control input must be UTF-8 JSON bytes.")

  @doc "Reads all summary pages through an injected binding-neutral carrier."
  @spec enumerate(document(), (document() -> {:ok, document()} | {:error, term()}), keyword()) ::
          {:ok, Enumeration.t()} | {:error, term()}
  def enumerate(first_request, carrier, opts \\ []) when is_function(carrier, 1) do
    with {:ok, request} <- validate(first_request),
         :ok <- require_start_request(request),
         {:ok, state} <- Enumeration.new(enumeration_options(request, opts)) do
      enumerate_pages(request, carrier, state)
    end
  end

  @doc "Validates one atomic detail reply against a completed enumeration."
  @spec validate_details(document(), document(), Enumeration.t(), keyword()) ::
          {:ok, [map()]} | {:error, DASP.Error.t()}
  def validate_details(request, reply, %Enumeration{} = enumeration, opts \\ []) do
    DASP.Wire.protect(fn ->
      limits = enumeration.limits || Keyword.get(opts, :limits, %{})
      validate_detail_control_bytes!(limits, request, reply)

      request = valid_document!(request)
      reply = valid_document!(reply)

      if request["operation"] != "capabilities.get" or request["kind"] != "request" or
           reply["operation"] != "capabilities.get" or reply["kind"] != "reply",
         do: fail(:invalid_request, "Expected a capabilities.get request and reply.")

      if not enumeration.complete,
        do: fail(:contract_violation, "Capability enumeration is incomplete.")

      if request["snapshot"] != enumeration.snapshot or reply["snapshot"] != enumeration.snapshot or
           reply["profile"] != enumeration.profile or
           reply["resolved_view"] != enumeration.resolved_view,
         do: fail(:contract_violation, "Detail reply changed the discovery context.")

      if is_integer(limits["detail_items"]) and
           length(request["capabilities"]) > limits["detail_items"],
         do: fail(:request_limit, "Detail request exceeds the selected item limit.")

      validate_detail_opaque_values!(limits, request, reply)

      requested = Enum.map(request["capabilities"], &capability_key/1)
      returned = Enum.map(reply["details"], &capability_key(&1["capability"]))

      if length(requested) != length(Enum.uniq(requested)),
        do: fail(:invalid_request, "Detail request contains a duplicate capability identity.")

      if requested != returned,
        do: fail(:contract_violation, "Detail reply is not atomic and in request order.")

      Enum.each(reply["details"], fn detail ->
        identity = detail["capability"]
        ensure_profile!(identity, enumeration.profile)

        if is_integer(limits["presentation_bytes"]) do
          Enum.each(~w(label description), fn field ->
            if is_binary(detail[field]) and
                 byte_size(detail[field]) > limits["presentation_bytes"],
               do: fail(:contract_violation, "Detail presentation value exceeds its byte limit.")
          end)
        end

        if not MapSet.member?(enumeration.capabilities, capability_key(identity)),
          do: fail(:contract_violation, "Detail is outside the advertised snapshot.")

        case Manifest.validate(detail["schemas"], Keyword.put(opts, :limits, limits)) do
          {:ok, _manifest} -> :ok
          {:error, error} -> raise error
        end
      end)

      reply["details"]
    end)
  end

  @doc false
  def capability_key(%{
        "profile_uri" => profile_uri,
        "profile_version" => profile_version,
        "command" => command
      }),
      do: {profile_uri, profile_version, command}

  defp enumerate_pages(request, carrier, state) do
    with {:ok, reply} <- carrier.(request),
         {:ok, state} <- push_list_response(state, reply) do
      if state.complete do
        {:ok, state}
      else
        with {:ok, next_request} <-
               new("capabilities.list", "request", %{"continuation" => state.continuation}) do
          enumerate_pages(next_request, carrier, state)
        end
      end
    end
  end

  defp push_list_response(state, response) do
    validator = if is_binary(response), do: &decode/1, else: &validate/1

    case validator.(response) do
      {:ok, %{"operation" => "capabilities.list", "kind" => "failure"} = failure} ->
        {:error, failure}

      {:ok, %{"operation" => "capabilities.list", "kind" => "reply"}} ->
        Enumeration.push(state, response)

      {:ok, _document} ->
        error(:invalid_request, "Expected a capabilities.list reply or failure.")

      {:error, error} ->
        {:error, error}
    end
  end

  defp enumeration_options(request, opts) do
    limits = request["limits"]
    max_pages = limits["view_items"] + 1

    opts
    |> Keyword.put(:limits, limits)
    |> Keyword.put(:actor, request["actor"])
    |> Keyword.put_new(:max_pages, max_pages)
    |> Keyword.put_new(:max_items, limits["view_items"])
    |> Keyword.put_new(:max_control_bytes, limits["control_bytes"] * max_pages)
  end

  defp require_start_request(%{
         "operation" => "capabilities.list",
         "kind" => "request",
         "start" => _,
         "actor" => _,
         "limits" => _
       }),
       do: :ok

  defp require_start_request(_),
    do: error(:invalid_request, "Enumeration must start with a capabilities.list start request.")

  defp ensure_profile!(identity, profile) do
    if identity["profile_uri"] != profile["uri"] or
         identity["profile_version"] != profile["version"],
       do: fail(:contract_violation, "Capability identity differs from the snapshot profile.")
  end

  defp valid_document!(document) do
    validator = if is_binary(document), do: &decode/1, else: &validate/1

    case validator.(document) do
      {:ok, valid} -> valid
      {:error, error} -> raise error
    end
  end

  defp validate_detail_control_bytes!(limits, request, reply) do
    if exceeds_control_limit?(limits, request),
      do: fail(:request_limit, "Detail request exceeds the selected control-byte limit.")

    if exceeds_control_limit?(limits, reply),
      do: fail(:contract_violation, "Detail reply exceeds the selected control-byte limit.")
  end

  defp exceeds_control_limit?(%{"control_bytes" => maximum}, document)
       when is_integer(maximum),
       do: control_bytes(document) > maximum

  defp exceeds_control_limit?(_limits, _document), do: false

  defp control_bytes(document) when is_binary(document), do: byte_size(document)

  defp control_bytes(document) when is_map(document) and not is_struct(document),
    do: byte_size(DASP.JSON.encode!(document))

  defp control_bytes(_document), do: 0

  defp validate_detail_opaque_values!(%{"opaque_bytes" => maximum}, request, reply)
       when is_integer(maximum) do
    ensure_opaque_bytes!(request["snapshot"], maximum, :request_limit)

    Enum.each([reply["snapshot"], reply["resolved_view"]], fn value ->
      ensure_opaque_bytes!(value, maximum, :contract_violation)
    end)

    Enum.each(reply["details"], fn detail ->
      manifest = detail["schemas"]

      Enum.each([manifest["input_root"], manifest["output_root"]], fn value ->
        ensure_opaque_bytes!(value, maximum, :contract_violation)
      end)

      Enum.each(manifest["resources"], fn descriptor ->
        ensure_opaque_bytes!(descriptor["resource"], maximum, :contract_violation)
      end)
    end)
  end

  defp validate_detail_opaque_values!(_limits, _request, _reply), do: :ok

  defp ensure_opaque_bytes!(value, maximum, code) do
    if is_binary(value) and byte_size(value) > maximum,
      do: fail(code, "Discovery opaque value exceeds its byte limit.")
  end

  defp error(code, message), do: {:error, %DASP.Error{code: code, message: message}}
end
