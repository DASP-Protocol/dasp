defmodule Jido.Seigyo.ExecutionTarget do
  @moduledoc "One safe execution target summary."

  @schema Zoi.object(
            %{
              "id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :target_id, []}),
              "name" => Zoi.string() |> Zoi.min(1) |> Zoi.max(128),
              "status" => Zoi.enum(~w(ready draining unavailable)),
              "isolation" =>
                Zoi.list(Zoi.enum(~w(trusted_local container vm remote)), unique_items: true)
                |> Zoi.min(1)
                |> Zoi.max(8),
              "network" =>
                Zoi.list(Zoi.enum(~w(denied restricted allowed)), unique_items: true)
                |> Zoi.min(1)
                |> Zoi.max(8),
              "sandbox_profiles" =>
                Zoi.list(
                  Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
                  unique_items: true
                )
                |> Zoi.max(32),
              "security_boundary" => Zoi.enum(~w(none container vm))
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end

defmodule Jido.Seigyo.SandboxProfile do
  @moduledoc "One server-approved Sandbox profile summary."

  @schema Zoi.object(
            %{
              "id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []}),
              "name" => Zoi.string() |> Zoi.min(1) |> Zoi.max(128),
              "target_id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :target_id, []}),
              "isolation" => Zoi.enum(~w(trusted_local container vm remote)),
              "network" => Zoi.enum(~w(denied restricted allowed)),
              "workspace_binding" => Zoi.enum(~w(borrowed managed_copy)),
              "workspace_runtime_root" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :runtime_path, []})
                |> Zoi.nullable(),
              "fault_boundary" => Zoi.enum(~w(beam_process os_process container vm)),
              "security_boundary" => Zoi.enum(~w(none container vm))
            },
            unrecognized_keys: :error
          )

  @spec schema() :: Zoi.schema()
  def schema, do: @schema
end

defmodule Jido.Seigyo.ExecutionCatalog do
  @moduledoc "The bounded safe catalog of execution targets and Sandbox profiles."

  use Jido.Signal,
    type: "jido.client.v1.execution.catalog",
    default_source: "/jido/code/server",
    schema:
      Zoi.object(
        %{
          "version" => Zoi.literal(1),
          "targets" => Zoi.list(Jido.Seigyo.ExecutionTarget.schema()) |> Zoi.max(64),
          "sandbox_profiles" => Zoi.list(Jido.Seigyo.SandboxProfile.schema()) |> Zoi.max(128)
        },
        unrecognized_keys: :error
      )
end
