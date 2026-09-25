defmodule Jido.Seigyo.Client.Value do
  @moduledoc false

  alias Jido.Seigyo.Client.Error

  # The remote client does not accept private provider reasoning. Native
  # protocol values can contain it before the server applies disclosure policy.
  def public_reasoning_fields do
    %{thinking: Zoi.literal(""), thinking_truncated: Zoi.literal(false)}
  end

  @doc false
  def canonical(value, module, schema_function, versioned, _opts) do
    data = to_data(value)
    data = if versioned, do: Map.put(data, "version", 1), else: data

    case Zoi.parse(apply(module, schema_function, []), data) do
      {:ok, _} -> :ok
      {:error, [error | _]} -> {:error, error}
    end
  end

  @doc false
  def to_data(%Jido.Seigyo.Error{} = error), do: Jido.Seigyo.Error.to_map(error)
  def to_data(%_{} = value), do: value |> Map.from_struct() |> to_data()

  def to_data(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {to_string(key), to_data(item)} end)

  def to_data(values) when is_list(values), do: Enum.map(values, &to_data/1)
  def to_data(value), do: value

  def parse(schema, value) do
    case Zoi.parse(schema, value) do
      {:ok, valid} -> {:ok, valid}
      {:error, issues} -> {:error, Error.new(:protocol, {:invalid_client_value, issues})}
    end
  end

  def invalid(value), do: {:error, Error.new(:protocol, {:invalid_client_value, value})}
end
