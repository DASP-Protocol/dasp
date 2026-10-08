defmodule DASP.Signal.Fields do
  @moduledoc false
  # These fields are assembled when a signal module compiles. Each signal
  # module still defines its complete data schema.
  alias DASP.Signal.Validation

  @identifier ~r/\A[A-Za-z0-9._:-]{1,128}\z/
  @name ~r/\A[a-z][a-z0-9_.-]{0,127}\z/

  def identifier, do: Zoi.string() |> Zoi.regex(@identifier)
  def name, do: Zoi.string() |> Zoi.regex(@name)
  def cursor, do: integer(0)
  def sequence, do: integer(1)
  def uri, do: Zoi.string() |> Zoi.refine({Validation, :uri, []})
  def nonempty_string, do: Zoi.string() |> Zoi.min(1)

  def json_object,
    do: Zoi.map(Zoi.string(), Zoi.any() |> Zoi.refine({Validation, :json_value, []}))

  def profile do
    Zoi.map(
      %{"id" => uri(), "version" => nonempty_string()},
      unrecognized_keys: :error
    )
  end

  def error do
    Zoi.map(
      %{"code" => name(), "message" => Zoi.string(), "retryable" => Zoi.boolean()},
      unrecognized_keys: :error
    )
  end

  def identifier?(value) when is_binary(value), do: Regex.match?(@identifier, value)
  def identifier?(_), do: false

  defp integer(minimum),
    do: Zoi.integer() |> Zoi.gte(minimum) |> Zoi.lte(DASP.JSON.max_integer())
end
