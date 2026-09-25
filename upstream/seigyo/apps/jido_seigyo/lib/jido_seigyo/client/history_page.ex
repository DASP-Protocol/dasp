defmodule Jido.Seigyo.Client.HistoryPage do
  @moduledoc "One bounded page of ordered Session history."

  alias Jido.Seigyo.Client.HistoryEntry

  @fields Jido.Seigyo.Schema.fields(
            Jido.Seigyo.HistoryPage.schema(),
            ~w(session_id entries next_cursor)a,
            projections: %{entries: HistoryEntry.schema()}
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
    Jido.Seigyo.Contract.history_page(
      %{
        "entries" => Enum.map(page.entries, &%{"sequence" => &1.sequence}),
        "next_cursor" => page.next_cursor
      },
      opts
    )
  end

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.HistoryPage.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, entries} <- map_entries(data["entries"]) do
      Jido.Seigyo.Client.Value.parse(
        @schema,
        %__MODULE__{
          session_id: data["session_id"],
          entries: entries,
          next_cursor: data["next_cursor"]
        }
      )
    end
  end

  defp map_entries(entries) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case HistoryEntry.from_data(entry) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp map_entries(entries), do: Jido.Seigyo.Client.Value.invalid(entries)
end
