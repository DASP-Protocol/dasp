defmodule Jido.Seigyo do
  @moduledoc """
  The data contract for the version 1 Seigyo Protocol coding profile.

  Each custom Signal has a Zoi schema for string-keyed data. After
  `Jido.Signal.deserialize/1` checks the envelope, `validate/1` checks that
  its type and data belong to this protocol. This module also publishes the
  exact capability catalog used by clients and servers.
  """

  alias Jido.Seigyo.{Catalog, Error, Update}

  @version 1
  @profile "coding"
  @update_event_types Update.event_types()
  @draft_operations []

  @spec version() :: pos_integer()
  def version, do: @version

  @spec profile() :: String.t()
  def profile, do: @profile

  @spec operations([String.t()]) :: [String.t()]
  def operations(features \\ []), do: Catalog.operation_names(features)

  @spec controls() :: [String.t()]
  def controls, do: Catalog.control_names()

  @spec request_signal_types([String.t()]) :: [String.t()]
  def request_signal_types(features \\ []), do: Catalog.signal_types(:request, features)

  @spec result_signal_types([String.t()]) :: [String.t()]
  def result_signal_types(features \\ []), do: Catalog.signal_types(:result, features)

  @spec push_signal_types([String.t()]) :: [String.t()]
  def push_signal_types(features \\ []), do: Catalog.signal_types(:push, features)

  @spec update_event_types([String.t()]) :: [String.t()]
  def update_event_types(features \\ [])

  def update_event_types(features) when is_list(features) do
    if "seigyo.membership/1" in features,
      do: Jido.Seigyo.MembershipUpdate.event_types(),
      else: @update_event_types
  end

  @doc "Operations with data contracts but no advertised server implementation."
  @spec draft_operations() :: [String.t()]
  def draft_operations, do: @draft_operations

  @doc "Request Signal types that are defined but not advertised by the server."
  @spec draft_request_signal_types() :: [String.t()]
  def draft_request_signal_types, do: Catalog.draft_signal_types(:request)

  @doc "Result Signal types that are defined but not advertised by the server."
  @spec draft_result_signal_types() :: [String.t()]
  def draft_result_signal_types, do: Catalog.draft_signal_types(:result)

  @doc "Push Signal types that are defined but not advertised by the server."
  @spec draft_push_signal_types() :: [String.t()]
  def draft_push_signal_types, do: Catalog.draft_signal_types(:push)

  @spec capabilities(String.t(), [String.t()]) :: map()
  def capabilities(principal, features \\ []) when is_binary(principal) and is_list(features) do
    %{
      "version" => version(),
      "profile" => profile(),
      "principal" => principal,
      "operations" => operations(features),
      "controls" => controls(),
      "request_signal_types" => request_signal_types(features),
      "result_signal_types" => result_signal_types(features),
      "push_signal_types" => push_signal_types(features),
      "update_event_types" => update_event_types(features)
    }
  end

  @doc "Checks the type and data of a decoded Jido Code client Signal."
  @spec validate(term(), keyword()) :: {:ok, Jido.Signal.t()} | {:error, Error.t()}
  def validate(signal, opts \\ [])

  def validate(%Jido.Signal{type: type, data: data} = signal, opts) when is_list(opts) do
    case Catalog.signal_module(type,
           include_drafts: true,
           features: Keyword.get(opts, :features, [])
         ) do
      {:ok, module} -> finish(signal, module.validate_data(data))
      :error -> {:error, Error.new("invalid_field", "type")}
    end
  end

  def validate(_, _), do: {:error, Error.new("invalid_field", "type")}

  defp finish(signal, {:ok, _data}), do: {:ok, signal}
  defp finish(_signal, {:error, errors}), do: {:error, Error.from_zoi(errors)}
end
