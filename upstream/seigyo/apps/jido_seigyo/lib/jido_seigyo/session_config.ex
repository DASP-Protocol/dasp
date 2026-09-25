defmodule Jido.Seigyo.SessionConfig do
  @moduledoc "Closed effective Session configuration and client-requested changes."

  @json_integer Zoi.integer()
                |> Zoi.min(0)
                |> Zoi.refine({Jido.Seigyo.Contract, :json_integer, []})
  @reference Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :reference, []})

  @model_schema Zoi.object(
                  %{
                    "id" => Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :model, []}),
                    "reasoning_level" =>
                      Zoi.enum(~w(none minimal low medium high xhigh max ultra))
                  },
                  unrecognized_keys: :error
                )
  @context_schema Zoi.object(
                    %{
                      "mode" => Zoi.enum(~w(managed full rolling)),
                      "target_tokens" => @json_integer |> Zoi.min(1_024),
                      "preserve_recent_turns" => @json_integer |> Zoi.max(1_000),
                      "compaction_policy" => Zoi.enum(~w(none summarize))
                    },
                    unrecognized_keys: :error
                  )
  @skill_schema Zoi.object(
                  %{
                    "id" => @reference,
                    "version" => @reference |> Zoi.nullable(),
                    "digest" =>
                      Zoi.string()
                      |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []})
                      |> Zoi.nullable()
                  },
                  unrecognized_keys: :error
                )
  @plugin_schema Zoi.object(
                   %{
                     "id" => @reference,
                     "version" => @reference |> Zoi.nullable(),
                     "capabilities" =>
                       Zoi.list(
                         Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :name, []}),
                         unique_items: true
                       )
                       |> Zoi.max(64)
                   },
                   unrecognized_keys: :error
                 )
  @tool_profile_schema Zoi.object(
                         %{
                           "id" => @reference,
                           "version" => @reference,
                           "digest" =>
                             Zoi.string()
                             |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []})
                         },
                         unrecognized_keys: :error
                       )
  @sandbox_schema Zoi.object(
                    %{
                      "id" =>
                        Zoi.string()
                        |> Zoi.refine({Jido.Seigyo.Contract, :sandbox_id, []}),
                      "profile" => @reference
                    },
                    unrecognized_keys: :error
                  )
  @execution_schema Zoi.object(
                      %{
                        "workspace_id" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :workspace_id, []}),
                        "target_id" =>
                          Zoi.string()
                          |> Zoi.refine({Jido.Seigyo.Contract, :target_id, []}),
                        "isolation" => Zoi.enum(~w(trusted_local container vm remote)),
                        "network" => Zoi.enum(~w(denied restricted allowed)),
                        "sandbox" => @sandbox_schema |> Zoi.nullable()
                      },
                      unrecognized_keys: :error
                    )
  @fields %{
    "model" => @model_schema,
    "context" => @context_schema,
    "skills" => Zoi.list(@skill_schema) |> Zoi.max(64),
    "plugins" => Zoi.list(@plugin_schema) |> Zoi.max(64),
    "tool_profile" => @tool_profile_schema,
    "execution" => @execution_schema,
    "instructions" =>
      Zoi.string() |> Zoi.refine({Jido.Seigyo.Contract, :session_instructions, []})
  }
  @schema Zoi.object(
            Map.merge(@fields, %{
              "version" => Zoi.literal(1),
              "revision" => @json_integer,
              "state" => Zoi.enum(~w(effective pending)),
              "profile" => Zoi.literal("coding"),
              "digest" =>
                Zoi.string()
                |> Zoi.refine({Jido.Seigyo.Contract, :sha256, []})
            }),
            unrecognized_keys: :error
          )
          |> Zoi.refine({__MODULE__, :valid_digest, []})
  @patch_schema Zoi.object(
                  @fields
                  |> Map.delete("tool_profile")
                  |> Map.new(fn {name, schema} -> {name, Zoi.optional(schema)} end),
                  unrecognized_keys: :error
                )
                |> Zoi.refine({Jido.Seigyo.Contract, :config_patch, []})

  @digest_fields [
    "version",
    "profile",
    "model",
    "context",
    "skills",
    "plugins",
    "tool_profile",
    "execution",
    "instructions"
  ]

  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @spec patch_schema() :: Zoi.schema()
  def patch_schema, do: @patch_schema

  @spec model_schema() :: Zoi.schema()
  def model_schema, do: @model_schema

  @spec context_schema() :: Zoi.schema()
  def context_schema, do: @context_schema

  @spec skill_schema() :: Zoi.schema()
  def skill_schema, do: @skill_schema

  @spec plugin_schema() :: Zoi.schema()
  def plugin_schema, do: @plugin_schema

  @spec tool_profile_schema() :: Zoi.schema()
  def tool_profile_schema, do: @tool_profile_schema

  @spec sandbox_schema() :: Zoi.schema()
  def sandbox_schema, do: @sandbox_schema

  @spec execution_schema() :: Zoi.schema()
  def execution_schema, do: @execution_schema

  @spec digest(map()) :: String.t()
  def digest(config) when is_map(config) do
    config
    |> Map.take(@digest_fields)
    |> Jido.Seigyo.Digest.sha256()
  end

  @spec put_digest(map()) :: map()
  def put_digest(config) when is_map(config), do: Map.put(config, "digest", digest(config))

  @doc false
  def valid_digest(config, _opts) do
    if config["digest"] == digest(config) do
      :ok
    else
      {:error,
       Zoi.Error.custom_error(
         issue:
           {"configuration digest does not match", [jido_code: "invalid_field", field: "digest"]}
       )}
    end
  end
end
