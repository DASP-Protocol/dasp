defmodule DASP.Error do
  @moduledoc "A client error. Transport errors and timeouts do not prove rejection."
  defexception [:code, :message, :detail]

  @type t :: %__MODULE__{code: atom(), message: String.t(), detail: term()}

  @doc false
  def fail(code, message, detail \\ nil) do
    raise __MODULE__, code: code, message: message, detail: detail
  end
end
