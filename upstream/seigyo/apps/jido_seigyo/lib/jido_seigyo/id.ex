defmodule Jido.Seigyo.ID do
  @moduledoc "Typed UUID version 7 IDs from Jido Signal."

  @prefixes %{
    session: "ses_",
    command: "cmd_",
    workspace: "ws_",
    target: "tgt_",
    sandbox: "sbx_",
    mutation: "mut_",
    attachment: "att_",
    result: "res_",
    artifact: "art_",
    actor: "act_",
    actor_instance: "ain_"
  }

  @type kind ::
          :session
          | :command
          | :workspace
          | :target
          | :sandbox
          | :mutation
          | :attachment
          | :result
          | :artifact
          | :actor
          | :actor_instance

  @doc "JSON Schema patterns for the same closed ID kinds."
  @spec patterns() :: %{String.t() => String.t()}
  def patterns do
    uuid = "[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"

    @prefixes
    |> Map.new(fn {kind, prefix} -> {Atom.to_string(kind), "^" <> prefix <> uuid <> "$"} end)
    |> Map.put("signal", "^" <> uuid <> "$")
  end

  @spec generate(kind()) :: String.t()
  def generate(kind) when is_map_key(@prefixes, kind) do
    @prefixes[kind] <> Jido.Signal.ID.generate!()
  end

  @spec valid?(term(), kind()) :: boolean()
  def valid?(value, kind) when is_binary(value) and is_map_key(@prefixes, kind) do
    prefix = @prefixes[kind]

    byte_size(value) == byte_size(prefix) + 36 and
      String.starts_with?(value, prefix) and
      String.valid?(value) and
      value == String.downcase(value) and
      Jido.Signal.ID.valid?(binary_part(value, byte_size(prefix), 36))
  end

  def valid?(_, _), do: false
end
