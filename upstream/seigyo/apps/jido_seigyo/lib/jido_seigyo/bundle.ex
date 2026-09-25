defmodule Jido.Seigyo.Bundle do
  @moduledoc """
  Exact content identity for the frozen coding v1 release.

  This API needs no connection, server, or application process. The file index
  and algorithm are specified in the bundled release policy. Package versions
  and implementation revisions are not contract identities.
  """

  alias Jido.Seigyo.Digest

  @paths ~w(
    cases.json
    docs/adr/0019-client-websocket-wire.md
    docs/seigyo/coding-v1-baseline.md
    docs/seigyo/conformance.md
    docs/seigyo/delivery.md
    docs/seigyo/model.md
    docs/seigyo/release-policy.md
    docs/seigyo/signals.md
    docs/seigyo/wire.md
    frames.json
    operations.json
    schemas.json
    vectors.json
  )

  @doc "Reads the named normative bytes of the frozen baseline."
  @spec files() :: %{String.t() => binary()}
  def files, do: Map.new(@paths, &{&1, File.read!(path(&1))})

  @doc "Reads the published identity, independent of its implementation revision."
  @spec contract() :: map()
  def contract, do: "contract.json" |> path() |> File.read!() |> JSON.decode!()

  @doc "Computes the identity of the supplied exact normative files."
  @spec descriptor(%{String.t() => binary()}) :: map()
  def descriptor(files) when is_map(files) do
    index = %{
      "algorithm" => "seigyo-sha256-file-index-v1",
      "protocol" => 1,
      "profile" => "coding",
      "binding" => "phoenix-channel-websocket",
      "files" =>
        files
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(fn {name, bytes} ->
          %{
            "path" => name,
            "bytes" => byte_size(bytes),
            "sha256" => :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
          }
        end)
    }

    Map.put(index, "digest", Digest.sha256(index))
  end

  @doc "Rejects changed content, file inventory, identity, or descriptor fields."
  @spec verify(map(), %{String.t() => binary()}) :: :ok | {:error, :contract_mismatch}
  def verify(contract, files) do
    if contract == descriptor(files), do: :ok, else: {:error, :contract_mismatch}
  end

  defp path(name) do
    :jido_seigyo
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("seigyo/coding-v1")
    |> Path.join(name)
  end
end
