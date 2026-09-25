defmodule Jido.Seigyo.Client.UpdatesPage do
  @moduledoc "One bounded page of ordered Session updates."

  alias Jido.Seigyo.Client.Update

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.MembershipUpdatesPage.schema(),
            ~w(session_id after_sequence updates next_cursor)a,
            projections: %{updates: Update.schema()}
          )
  @schema Zoi.struct(__MODULE__, @fields, unrecognized_keys: :error)
          |> Zoi.refine({__MODULE__, :coherent_page, []})

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc false
  def coherent_page(%__MODULE__{} = page, opts) do
    Jido.Seigyo.Contract.updates_page(
      %{
        "session_id" => page.session_id,
        "after_sequence" => page.after_sequence,
        "updates" =>
          Enum.map(page.updates, fn update ->
            %{"session_id" => update.session_id, "sequence" => update.sequence}
          end),
        "next_cursor" => page.next_cursor
      },
      opts
    )
  end

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.MembershipUpdatesPage.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, updates} <- map_updates(data["updates"]) do
      Jido.Seigyo.Client.Value.parse(
        @schema,
        %__MODULE__{
          session_id: data["session_id"],
          after_sequence: data["after_sequence"],
          updates: updates,
          next_cursor: data["next_cursor"]
        }
      )
    end
  end

  defp map_updates(updates) when is_list(updates) do
    Enum.reduce_while(updates, {:ok, []}, fn update, {:ok, acc} ->
      case Update.from_data(update) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp map_updates(updates), do: Jido.Seigyo.Client.Value.invalid(updates)
end
