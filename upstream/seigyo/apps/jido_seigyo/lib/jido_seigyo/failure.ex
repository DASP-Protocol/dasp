defmodule Jido.Seigyo.Failure do
  @moduledoc "The version 1 failure Signal for a client operation."

  use Jido.Signal,
    type: "jido.client.v1.failure",
    default_source: "/jido/code/server",
    schema: Jido.Seigyo.Error.schema()
end
