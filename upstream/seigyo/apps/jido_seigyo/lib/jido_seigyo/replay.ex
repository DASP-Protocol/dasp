defmodule Jido.Seigyo.Replay do
  @moduledoc """
  A pure applied cursor with bounded evidence for duplicate Updates.

  Call `check/2` before application. Call `commit/2` only after application
  succeeds. Save the consumer state and this cursor together. This module
  performs no storage or acknowledgement on the server.

  A restored cursor without fingerprints cannot prove that an older Update
  is equivalent. Such a delivery returns `gap`; a conflicting fingerprint
  returns `conflict`. Fingerprints cover canonical Update data, not Signal
  envelope identities.
  """

  alias Jido.Seigyo.{Contract, Digest, Error, ID, Update}

  @enforce_keys [:session_id, :cursor, :window]
  defstruct [:session_id, :cursor, :window, fingerprints: %{}]

  @doc "Starts at an applied cursor with a duplicate evidence window of 1 to 1000 Updates."
  def new(session_id, opts \\ []) do
    with true <- ID.valid?(session_id, :session),
         true <- Keyword.keyword?(opts) and Keyword.keys(opts) -- [:after, :window] == [],
         cursor = Keyword.get(opts, :after, 0),
         true <- is_integer(cursor) and cursor >= 0 and Contract.json_integer(cursor, []) == :ok,
         window = Keyword.get(opts, :window, 256),
         true <- is_integer(window) and window in 1..1000 do
      {:ok, %__MODULE__{session_id: session_id, cursor: cursor, window: window}}
    else
      false -> {:error, Error.new("invalid_field", "replay")}
    end
  end

  @doc "Validates an Update and returns `:apply` or `:duplicate` without advancing."
  def check(%__MODULE__{} = replay, data) do
    with {:ok, data} <- validate(data),
         :ok <- same_session(replay, data) do
      sequence = data["sequence"]

      cond do
        sequence == replay.cursor + 1 -> {:ok, :apply}
        sequence > replay.cursor -> {:error, Error.new("gap", "sequence")}
        true -> compare(replay.fingerprints[sequence], Digest.sha256(data))
      end
    end
  end

  @doc "Advances after successful application; an equivalent duplicate is a no-op."
  def commit(%__MODULE__{} = replay, data) do
    case check(replay, data) do
      {:ok, :apply} ->
        cursor = data["sequence"]

        fingerprints =
          replay.fingerprints
          |> Map.put(cursor, Digest.sha256(data))
          |> Map.reject(fn {sequence, _digest} -> sequence <= cursor - replay.window end)

        {:ok, %{replay | cursor: cursor, fingerprints: fingerprints}}

      {:ok, :duplicate} ->
        {:ok, replay}

      {:error, _} = error ->
        error
    end
  end

  defp validate(data) do
    case Update.validate_data(data) do
      {:ok, value} -> {:ok, value}
      {:error, errors} -> {:error, Error.from_zoi(errors)}
    end
  end

  defp same_session(%{session_id: id}, %{"session_id" => id}), do: :ok
  defp same_session(_, _), do: {:error, Error.new("conflict", "session_id")}
  defp compare(nil, _digest), do: {:error, Error.new("gap", "sequence")}
  defp compare(digest, digest), do: {:ok, :duplicate}
  defp compare(_, _), do: {:error, Error.new("conflict", "sequence")}
end
