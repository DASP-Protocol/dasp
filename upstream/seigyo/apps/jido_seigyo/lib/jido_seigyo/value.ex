defmodule Jido.Seigyo.Value do
  @moduledoc """
  Bounded portable data for View content and Update payloads.

  Values use JSON-compatible primitives only. Maps have string keys. One tree
  has a 16 KiB size budget, at most four container levels, 32 keys per map,
  and 64 values per list. Strings have at most 8 KiB. Integer values stay in
  the exact integer range common to JSON clients.
  """

  @max_bytes 16_384
  @max_string 8_192
  @max_integer 9_007_199_254_740_991

  @spec check(term()) :: :ok | {:error, String.t()}
  def check(value) do
    case measure(value, 0, @max_bytes) do
      {:ok, _bytes} -> :ok
      error -> error
    end
  end

  defp measure(value, _depth, budget) when is_binary(value) do
    cond do
      byte_size(value) > min(@max_string, budget) -> {:error, "too_large"}
      not String.valid?(value) -> {:error, "invalid_field"}
      true -> {:ok, byte_size(value)}
    end
  end

  defp measure(value, _depth, budget) when is_integer(value) do
    if abs(value) <= @max_integer and budget >= 8,
      do: {:ok, 8},
      else: {:error, "too_large"}
  end

  defp measure(value, _depth, budget) when value in [nil, true, false] do
    if budget >= 1, do: {:ok, 1}, else: {:error, "too_large"}
  end

  defp measure(value, depth, budget) when is_map(value) and depth < 4 do
    if map_size(value) <= 32 and budget >= 1 do
      Enum.reduce_while(value, {:ok, 1}, fn {key, item}, {:ok, size} ->
        with {:ok, key_size} <- key_size(key),
             true <- size + key_size <= budget,
             {:ok, item_size} <- measure(item, depth + 1, budget - size - key_size) do
          {:cont, {:ok, size + key_size + item_size}}
        else
          false -> {:halt, {:error, "too_large"}}
          error -> {:halt, error}
        end
      end)
    else
      {:error, "too_large"}
    end
  end

  defp measure(value, depth, budget) when is_list(value) and depth < 4 do
    if length(value) <= 64 and budget >= 1 do
      Enum.reduce_while(value, {:ok, 1}, fn item, {:ok, size} ->
        case measure(item, depth + 1, budget - size) do
          {:ok, item_size} -> {:cont, {:ok, size + item_size}}
          error -> {:halt, error}
        end
      end)
    else
      {:error, "too_large"}
    end
  end

  defp measure(_, _, _), do: {:error, "invalid_field"}

  defp key_size(key) when is_binary(key) do
    if byte_size(key) in 1..64 and String.valid?(key),
      do: {:ok, byte_size(key)},
      else: {:error, "invalid_field"}
  end

  defp key_size(_), do: {:error, "invalid_field"}
end
