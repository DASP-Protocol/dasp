defmodule Jido.Seigyo.SessionConfigurationsPage do
  @moduledoc "One bounded page of saved Session configuration revisions."

  @revision Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})

  use Jido.Signal,
    type: "jido.client.v1.session.configurations.page",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "oldest_revision" => @revision,
          "after_revision" => @revision |> Zoi.nullable(),
          "configurations" => Zoi.list(Jido.Seigyo.SessionConfig.schema()) |> Zoi.max(100),
          "next_cursor" => @revision |> Zoi.nullable()
        },
        unrecognized_keys: :error
      )
      |> Zoi.refine({Jido.Seigyo.Contract, :configuration_history_page, []})
end
