defmodule Jido.Seigyo.Error do
  @moduledoc "A stable error code with an optional field name."

  @codes ~w(invalid_field invalid_id unsupported_version too_large conflict not_found gap unavailable)
  @schema Zoi.object(
            %{
              "version" => Zoi.literal(1),
              "code" => Zoi.enum(@codes),
              "field" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :name, []})
                |> Zoi.nullable()
            },
            unrecognized_keys: :error
          )

  use Splode.Error, class: :invalid, fields: [:code, :field, :message]

  @type t :: %__MODULE__{code: String.t(), field: String.t() | nil}

  @spec new(String.t(), String.t() | nil) :: t()
  def new(code, field \\ nil) when code in @codes,
    do: struct!(__MODULE__, code: code, field: field, message: code)

  @spec from_map(term()) :: {:ok, t()} | {:error, t()}
  def from_map(map) do
    case Zoi.parse(@schema, map) do
      {:ok, value} -> {:ok, new(value["code"], value["field"])}
      {:error, errors} -> {:error, from_zoi(errors)}
    end
  end

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec codes() :: [String.t()]
  def codes, do: @codes

  @doc false
  @spec from_zoi([Zoi.Error.t()]) :: t()
  def from_zoi([%Zoi.Error{} = error | _]) do
    opts =
      case error.issue do
        {_message, values} when is_list(values) -> values
        _ -> []
      end

    field =
      case error.path do
        [name | _] when is_binary(name) or is_atom(name) -> to_string(name)
        _ -> Keyword.get(opts, :field, "shape")
      end

    code = Keyword.get(opts, :jido_code)
    code = if code in @codes, do: code, else: default_code(field)
    new(code, field)
  end

  def from_zoi(_), do: new("invalid_field", "shape")

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = error) do
    %{"version" => Jido.Seigyo.version(), "code" => error.code, "field" => error.field}
  end

  defp default_code("version"), do: "unsupported_version"
  defp default_code(_), do: "invalid_field"
end
