defmodule Jido.Seigyo.Client.SessionConfiguration do
  @moduledoc "The effective and pending configuration for one Session."

  alias Jido.Seigyo.Client.{SessionConfig, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfiguration.schema(),
              ~w(session_id effective pending)a,
              projections: %{effective: SessionConfig.schema(), pending: SessionConfig.schema()}
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionConfiguration.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, effective} <- SessionConfig.from_data(data["effective"]),
         {:ok, pending} <- pending(data["pending"]) do
      Value.parse(@schema, %__MODULE__{
        session_id: data["session_id"],
        effective: effective,
        pending: pending
      })
    end
  end

  defp pending(nil), do: {:ok, nil}
  defp pending(value), do: SessionConfig.from_data(value)
end

defmodule Jido.Seigyo.Client.SessionConfigured do
  @moduledoc "The result of one Session configuration mutation."

  alias Jido.Seigyo.Client.{SessionConfig, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfigured.schema(),
              ~w(mutation_id session_id sequence disposition previous_revision effective_from config)a,
              projections: %{config: SessionConfig.schema()}
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionConfigured.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, config} <- SessionConfig.from_data(data["config"]) do
      Value.parse(@schema, %__MODULE__{
        mutation_id: data["mutation_id"],
        session_id: data["session_id"],
        sequence: data["sequence"],
        disposition: data["disposition"],
        previous_revision: data["previous_revision"],
        effective_from: data["effective_from"],
        config: config
      })
    end
  end
end
