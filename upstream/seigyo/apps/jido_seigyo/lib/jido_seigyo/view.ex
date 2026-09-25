defmodule Jido.Seigyo.View do
  @moduledoc "The version 1 Session View Signal."

  @active_command_schema Zoi.object(
                           %{
                             "command_id" =>
                               Zoi.string()
                               |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
                             "state" => Zoi.enum(~w(accepted dispatched))
                           },
                           unrecognized_keys: :error
                         )
  @command_outcome_schema Zoi.object(
                            %{
                              "command_id" =>
                                Zoi.string()
                                |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
                              "state" => Zoi.enum(~w(completed failed cancelled uncertain)),
                              "sequence" =>
                                Zoi.integer()
                                |> Zoi.min(1)
                                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
                            },
                            unrecognized_keys: :error
                          )
  @message_schema Zoi.object(
                    %{
                      "command_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []}),
                      "role" => Zoi.enum(~w(user assistant)),
                      "text" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :history_text, []})
                    },
                    unrecognized_keys: :error
                  )
  @workspace_schema Zoi.object(
                      %{
                        "id" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
                        "name" => Zoi.string() |> Zoi.min(1) |> Zoi.max(256),
                        "ownership" => Zoi.enum(~w(borrowed managed unknown)),
                        "mode" => Zoi.enum(~w(shared exclusive isolated unknown)),
                        "status" => Zoi.enum(~w(ready unavailable))
                      },
                      unrecognized_keys: :error
                    )
  @execution_schema Zoi.object(
                      %{
                        "target_id" =>
                          Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :target_id, []}),
                        "sandbox_id" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :sandbox_id, []})
                          |> Zoi.nullable(),
                        "sandbox_profile" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :reference, []})
                          |> Zoi.nullable(),
                        "isolation" => Zoi.enum(~w(trusted_local container vm remote)),
                        "network" => Zoi.enum(~w(denied restricted allowed)),
                        "status" => Zoi.enum(~w(ready unavailable))
                      },
                      unrecognized_keys: :error
                    )
  @content_schema Zoi.object(
                    %{
                      "active_command" => @active_command_schema |> Zoi.nullable(),
                      "last_result" => Zoi.string() |> Zoi.max(1_000) |> Zoi.nullable(),
                      "last_result_command_id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :command_id, []})
                        |> Zoi.nullable(),
                      "messages" => Zoi.list(@message_schema) |> Zoi.max(30),
                      "messages_truncated" => Zoi.boolean(),
                      "recent_outcomes" => Zoi.list(@command_outcome_schema) |> Zoi.max(10),
                      "execution" => @execution_schema,
                      "workspace" => @workspace_schema
                    },
                    unrecognized_keys: :error
                  )
                  |> Zoi.refine({Jido.Seigyo.Contract, :view_content, []})

  use Jido.Signal,
    type: "jido.client.v1.view",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "session_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_id, []}),
          "session_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "agent_revision" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
            |> Zoi.nullable(),
          "event_cursor" =>
            Zoi.integer()
            |> Zoi.min(0)
            |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []}),
          "lifecycle" => Zoi.enum(~w(open closing closed)),
          "content" => @content_schema
        },
        unrecognized_keys: :error
      )

  @doc "Returns the closed version 1 View content schema."
  @spec content_schema() :: Zoi.schema()
  def content_schema, do: @content_schema

  @doc false
  def active_command_schema, do: @active_command_schema
  @doc false
  def command_outcome_schema, do: @command_outcome_schema
  @doc false
  def message_schema, do: @message_schema
  @doc false
  def workspace_schema, do: @workspace_schema
  @doc false
  def execution_schema, do: @execution_schema
end
