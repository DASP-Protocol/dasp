defmodule Jido.Seigyo.Client.Error do
  @moduledoc "A connection, timeout, or wire-protocol error from the client."

  @enforce_keys [:kind, :reason]
  defexception [:kind, :reason, message: "Jido Code client error"]

  @type kind :: :connection | :protocol | :timeout
  @type t :: %__MODULE__{kind: kind(), reason: term(), message: String.t()}

  @spec new(kind(), term()) :: t()
  def new(kind, reason) when kind in [:connection, :protocol, :timeout] do
    %__MODULE__{
      kind: kind,
      reason: reason,
      message: "Jido Code client #{kind} error"
    }
  end
end
