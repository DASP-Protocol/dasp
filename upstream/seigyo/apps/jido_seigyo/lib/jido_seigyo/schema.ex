defmodule Jido.Seigyo.Schema do
  @moduledoc """
  Schema field selection for typed projections of canonical protocol values.

  Field names and projection modules are compile-time declarations. This module
  never creates atoms from input or interprets execution policy. Wire validation
  uses the complete original schema before a client builds its projection.
  """

  @doc "Selects declared fields, with optional wire paths and nested struct projections."
  @spec fields(Zoi.schema(), [atom()], keyword()) :: map()
  def fields(schema, names, opts \\ []) do
    paths = Keyword.get(opts, :paths, %{})
    projections = Keyword.get(opts, :projections, %{})

    Map.new(names, fn name ->
      source = field(schema, Map.get(paths, name, Atom.to_string(name)))

      selected =
        if Map.has_key?(projections, name), do: project(source, projections[name]), else: source

      {name, selected}
    end)
  end

  @doc "Selects a canonical field or nested field path."
  @spec field(Zoi.schema(), String.t() | [String.t()]) :: Zoi.schema()
  def field(schema, path) when is_list(path), do: Enum.reduce(path, schema, &field(&2, &1))

  def field(schema, name) when is_binary(name) do
    case fetch(schema, name) do
      {:ok, field} -> field
      :error -> raise KeyError, key: name, term: schema
    end
  end

  defp fetch(%Zoi.Types.Map{fields: fields}, name) do
    case List.keyfind(fields, name, 0) do
      nil -> :error
      {_, schema} -> {:ok, schema}
    end
  end

  defp fetch(%Zoi.Types.DiscriminatedUnion{schemas: schemas, values: values}, name),
    do: union_field(Enum.map(values, &Map.fetch!(schemas, &1)), name)

  defp fetch(%Zoi.Types.Union{schemas: schemas}, name), do: union_field(schemas, name)
  defp fetch(%Zoi.Types.Literal{value: nil}, _name), do: :error
  defp fetch(%Zoi.Types.Null{}, _name), do: :error

  defp union_field(schemas, name) do
    fields = Enum.map(schemas, &fetch(&1, name))

    if Enum.all?(fields, &(&1 == :error)) do
      :error
    else
      alternatives =
        Enum.map(fields, fn
          {:ok, field} -> field
          :error -> Zoi.literal(nil)
        end)
        |> Enum.uniq()

      case alternatives do
        [field] -> {:ok, field}
        fields -> {:ok, Zoi.union(fields)}
      end
    end
  end

  defp project(%Zoi.Types.Array{} = source, replacement),
    do: %{source | inner: project(source.inner, replacement)}

  defp project(%Zoi.Types.Union{} = source, replacement),
    do: %{source | schemas: Enum.map(source.schemas, &project(&1, replacement))}

  defp project(%Zoi.Types.Null{} = source, _replacement), do: source
  defp project(%Zoi.Types.Literal{value: nil} = source, _replacement), do: source

  defp project(_source, replacement), do: replacement
end
