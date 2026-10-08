defmodule DASP.Discovery.ResourceVerifier do
  @moduledoc """
  Incremental exact-byte verifier for a discovered schema resource.

  The verifier does not decode, compile, evaluate, fetch, or retain the schema.
  A binding adapter supplies ordered bytes after transport decoding.
  """

  alias DASP.Discovery.Control
  import DASP.Error, only: [fail: 2]

  @enforce_keys [:descriptor, :hash]
  defstruct [:descriptor, :hash, bytes: 0]

  @type t :: %__MODULE__{}

  @doc "Starts exact-byte verification for one resource descriptor."
  @spec new(map()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def new(descriptor) do
    DASP.Wire.protect(fn ->
      validate_digest_algorithm!(descriptor)

      with {:ok, parsed} <-
             Zoi.parse(Control.resource_descriptor_schema(), descriptor, coerce: false),
           true <- parsed == descriptor do
        if not safe_identity?(descriptor["resource"]),
          do:
            fail(:unsafe_identity, "Resource identity is unsafe for local or remote resolution.")

        %__MODULE__{descriptor: descriptor, hash: :crypto.hash_init(:sha256)}
      else
        _ -> fail(:invalid_request, "Invalid discovery resource descriptor.")
      end
    end)
  end

  @doc "Adds one ordered decoded byte chunk."
  @spec update(t(), binary()) :: {:ok, t()} | {:error, DASP.Error.t()}
  def update(%__MODULE__{} = verifier, chunk) when is_binary(chunk) do
    DASP.Wire.protect(fn ->
      bytes = verifier.bytes + byte_size(chunk)

      if bytes > verifier.descriptor["byte_length"],
        do: fail(:length_mismatch, "Schema resource is longer than its declared byte length.")

      %{verifier | bytes: bytes, hash: :crypto.hash_update(verifier.hash, chunk)}
    end)
  end

  def update(%__MODULE__{}, _),
    do: error(:invalid_request, "A schema resource chunk must be a binary.")

  @doc "Finishes the length and optional SHA-256 verification."
  @spec finish(t()) :: {:ok, map()} | {:error, DASP.Error.t()}
  def finish(%__MODULE__{} = verifier) do
    DASP.Wire.protect(fn ->
      expected_length = verifier.descriptor["byte_length"]

      if verifier.bytes != expected_length,
        do: fail(:length_mismatch, "Schema resource byte length does not match its descriptor.")

      digest = :crypto.hash_final(verifier.hash)
      expected = get_in(verifier.descriptor, ["digest", "value"])

      if expected do
        expected_bytes = Base.decode16!(expected, case: :lower)

        if not :crypto.hash_equals(digest, expected_bytes),
          do: fail(:digest_mismatch, "Schema resource SHA-256 digest does not match.")
      end

      %{
        "resource" => verifier.descriptor["resource"],
        "byte_length" => verifier.bytes,
        "sha256" => Base.encode16(digest, case: :lower)
      }
    end)
  end

  @doc "Verifies an enumerable of ordered binary chunks without joining them."
  @spec verify(map(), Enumerable.t()) :: {:ok, map()} | {:error, DASP.Error.t()}
  def verify(descriptor, chunks) do
    with {:ok, verifier} <- new(descriptor),
         {:ok, verifier} <-
           Enum.reduce_while(chunks, {:ok, verifier}, fn chunk, {:ok, current} ->
             case update(current, chunk) do
               {:ok, next} -> {:cont, {:ok, next}}
               {:error, error} -> {:halt, {:error, error}}
             end
           end) do
      finish(verifier)
    end
  end

  @doc false
  def safe_identity?(identity) when is_binary(identity) do
    String.valid?(identity) and byte_size(identity) > 0 and byte_size(identity) <= 4096 and
      not String.contains?(identity, ["\0", "\\", "../", "..\\"]) and
      not String.starts_with?(identity, ["/", "./"]) and
      not Regex.match?(~r/\A(?:https?|file|ftp):/i, identity) and
      not Regex.match?(~r/\Aurn:[^\s]*:module(?::|\z)/i, identity)
  end

  def safe_identity?(_), do: false

  defp validate_digest_algorithm!(%{"digest" => %{"algorithm" => "sha-256"}}), do: :ok

  defp validate_digest_algorithm!(%{"digest" => %{"algorithm" => _}}),
    do: fail(:unsupported_digest, "Only sha-256 discovery resource digests are supported.")

  defp validate_digest_algorithm!(_), do: :ok

  defp error(code, message), do: {:error, %DASP.Error{code: code, message: message}}
end
