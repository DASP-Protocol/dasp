defmodule Jido.Seigyo.Client.ExecutionTarget do
  @moduledoc "A safe execution target advertised by the server."

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.ExecutionTarget.schema(),
              ~w(id name status isolation network sandbox_profiles security_boundary)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.SandboxProfile do
  @moduledoc "A safe server-approved Sandbox profile."

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SandboxProfile.schema(),
              ~w(id name target_id isolation network workspace_binding workspace_runtime_root fault_boundary security_boundary)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.ExecutionCatalog do
  @moduledoc "The typed safe execution catalog."

  alias Jido.Seigyo.Client.{ExecutionTarget, SandboxProfile, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.ExecutionCatalog.schema(),
              ~w(targets sandbox_profiles)a,
              projections: %{
                targets: ExecutionTarget.schema(),
                sandbox_profiles: SandboxProfile.schema()
              }
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.ExecutionCatalog.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, targets} <- struct_values(ExecutionTarget, data["targets"]),
         {:ok, profiles} <- struct_values(SandboxProfile, data["sandbox_profiles"]) do
      Value.parse(@schema, %__MODULE__{targets: targets, sandbox_profiles: profiles})
    end
  end

  defp struct_values(module, values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      attrs = Map.new(value, fn {key, item} -> {String.to_existing_atom(key), item} end)

      case Value.parse(module.schema(), struct!(module, attrs)) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  rescue
    _ -> Value.invalid(values)
  end

  defp struct_values(_module, values), do: Value.invalid(values)
end
