defmodule Jido.Seigyo.Client.Attachment do
  @moduledoc "Client-safe state for one immutable Attachment upload."

  alias Jido.Seigyo.Client.Value
  alias Jido.Seigyo.Error

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.Attachment.schema(),
              ~w(attachment_id session_id state name media_type size sha256 uploaded_bytes next_chunk_index error)a,
              projections: %{error: Zoi.struct(Error) |> Zoi.nullable()}
            )
          )
          |> Zoi.refine({Value, :canonical, [Jido.Seigyo.Attachment, :schema, true]})

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.Attachment.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, error} <- parse_error(data["error"]) do
      Value.parse(@schema, %__MODULE__{
        attachment_id: data["attachment_id"],
        session_id: data["session_id"],
        state: data["state"],
        name: data["name"],
        media_type: data["media_type"],
        size: data["size"],
        sha256: data["sha256"],
        uploaded_bytes: data["uploaded_bytes"],
        next_chunk_index: data["next_chunk_index"],
        error: error
      })
    end
  end

  defp parse_error(nil), do: {:ok, nil}
  defp parse_error(value), do: Error.from_map(value)
end
