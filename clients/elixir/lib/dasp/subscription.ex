defmodule DASP.Subscription do
  @moduledoc "A bounded subscription owned by its consumer process. Use DASP.next/2 or DASP.signals/1."
  @enforce_keys [:client, :ref, :owner]
  defstruct [:client, :ref, :owner]
end
