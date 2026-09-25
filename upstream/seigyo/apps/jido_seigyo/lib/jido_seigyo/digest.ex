defmodule Jido.Seigyo.Digest do
  @moduledoc "Portable SHA-256 identities for closed Seigyo data."

  @spec sha256(term()) :: String.t()
  def sha256(value) do
    value
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_json(nil), do: "null"
  defp canonical_json(true), do: "true"
  defp canonical_json(false), do: "false"
  defp canonical_json(value) when is_integer(value), do: Integer.to_string(value)
  defp canonical_json(value) when is_binary(value), do: JSON.encode!(value)

  defp canonical_json(values) when is_list(values) do
    "[" <> Enum.map_join(values, ",", &canonical_json/1) <> "]"
  end

  defp canonical_json(value) when is_map(value) do
    entries =
      value
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",", fn {key, item} ->
        canonical_json(key) <> ":" <> canonical_json(item)
      end)

    "{" <> entries <> "}"
  end
end
