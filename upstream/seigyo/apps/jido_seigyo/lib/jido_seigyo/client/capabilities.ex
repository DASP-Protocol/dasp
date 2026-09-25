defmodule Jido.Seigyo.Client.Capabilities do
  @moduledoc "The protocol capabilities negotiated during the WebSocket join."

  @signal_type Zoi.string()
               |> Zoi.refine({Jido.Seigyo.Contract, :signal_type, []})

  @fields %{
    version: Zoi.literal(1),
    profile: Zoi.string() |> Zoi.min(1) |> Zoi.max(64),
    principal: Zoi.string() |> Zoi.min(1) |> Zoi.max(256),
    operations:
      Zoi.list(Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :name, []}),
        unique_items: true
      )
      |> Zoi.min(1)
      |> Zoi.max(64),
    controls:
      Zoi.list(Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :name, []}),
        unique_items: true
      )
      |> Zoi.min(1)
      |> Zoi.max(64),
    request_signal_types:
      Zoi.list(@signal_type, unique_items: true)
      |> Zoi.min(1)
      |> Zoi.max(64),
    result_signal_types:
      Zoi.list(@signal_type, unique_items: true)
      |> Zoi.min(1)
      |> Zoi.max(64),
    push_signal_types:
      Zoi.list(@signal_type, unique_items: true)
      |> Zoi.min(1)
      |> Zoi.max(64),
    update_event_types:
      Zoi.list(
        Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :name, []}),
        unique_items: true
      )
      |> Zoi.min(1)
      |> Zoi.max(64)
  }
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  @spec require_operation(t(), String.t(), String.t() | nil, String.t()) ::
          :ok | {:error, Jido.Seigyo.Client.Error.t()}
  def require_operation(%__MODULE__{} = capabilities, operation, request_type, result_type)
      when is_binary(operation) and (is_binary(request_type) or is_nil(request_type)) and
             is_binary(result_type) do
    cond do
      operation not in capabilities.operations ->
        unsupported(:unsupported_operation)

      is_binary(request_type) and request_type not in capabilities.request_signal_types ->
        unsupported(:unsupported_request_signal)

      result_type not in capabilities.result_signal_types ->
        unsupported(:unsupported_result_signal)

      true ->
        :ok
    end
  end

  @doc false
  @spec require_control(t(), String.t(), [String.t()]) ::
          :ok | {:error, Jido.Seigyo.Client.Error.t()}
  def require_control(%__MODULE__{} = capabilities, control, push_types)
      when is_binary(control) and is_list(push_types) do
    cond do
      control not in capabilities.controls ->
        unsupported(:unsupported_control)

      not Enum.all?(push_types, &(&1 in capabilities.push_signal_types)) ->
        unsupported(:unsupported_push_signal)

      true ->
        :ok
    end
  end

  @doc false
  def from_data(data) when is_map(data) do
    if Enum.sort(Map.keys(data)) ==
         ~w(controls operations principal profile push_signal_types request_signal_types result_signal_types update_event_types version) do
      value = %__MODULE__{
        version: data["version"],
        profile: data["profile"],
        principal: data["principal"],
        operations: data["operations"],
        controls: data["controls"],
        request_signal_types: data["request_signal_types"],
        result_signal_types: data["result_signal_types"],
        push_signal_types: data["push_signal_types"],
        update_event_types: data["update_event_types"]
      }

      Jido.Seigyo.Client.Value.parse(@schema, value)
    else
      Jido.Seigyo.Client.Value.invalid(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp unsupported(reason), do: {:error, Jido.Seigyo.Client.Error.new(:protocol, reason)}
end
