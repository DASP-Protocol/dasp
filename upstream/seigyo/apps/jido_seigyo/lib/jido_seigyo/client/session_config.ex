defmodule Jido.Seigyo.Client.ToolProfile do
  @moduledoc "The exact server tool surface pinned by a Session configuration."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.tool_profile_schema(),
              ~w(id version digest)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.ModelConfig do
  @moduledoc "The model choice pinned by a Session configuration."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.model_schema(),
              ~w(id reasoning_level)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.ContextConfig do
  @moduledoc "The server-managed context policy."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.context_schema(),
              ~w(mode target_tokens preserve_recent_turns compaction_policy)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.SkillRef do
  @moduledoc "One enabled skill reference."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.skill_schema(),
              ~w(id version digest)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.PluginRef do
  @moduledoc "One enabled plugin reference."
  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.plugin_schema(),
              ~w(id version capabilities)a
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema
end

defmodule Jido.Seigyo.Client.SandboxConfig do
  @moduledoc "One Sandbox binding in a Session execution policy."

  alias Jido.Seigyo.Client.Value

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(Jido.Seigyo.SessionConfig.sandbox_schema(), ~w(id profile)a)
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema

  @doc false
  def from_data(nil), do: {:ok, nil}

  def from_data(%{"id" => id, "profile" => profile} = data) when map_size(data) == 2 do
    Value.parse(@schema, %__MODULE__{id: id, profile: profile})
  end

  def from_data(data), do: Value.invalid(data)
end

defmodule Jido.Seigyo.Client.ExecutionConfig do
  @moduledoc "The Workspace identity and execution placement policy."

  alias Jido.Seigyo.Client.{SandboxConfig, Value}

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.execution_schema(),
              ~w(workspace_id target_id isolation network sandbox)a,
              projections: %{sandbox: SandboxConfig.schema()}
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)
  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <-
           Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionConfig.execution_schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, sandbox} <- SandboxConfig.from_data(data["sandbox"]) do
      Value.parse(@schema, %__MODULE__{
        workspace_id: data["workspace_id"],
        target_id: data["target_id"],
        isolation: data["isolation"],
        network: data["network"],
        sandbox: sandbox
      })
    end
  end
end

defmodule Jido.Seigyo.Client.SessionConfig do
  @moduledoc "A typed effective or pending Session configuration."

  alias Jido.Seigyo.Client.{
    ContextConfig,
    ExecutionConfig,
    ModelConfig,
    PluginRef,
    SkillRef,
    ToolProfile
  }

  alias Jido.Seigyo.Client.Value

  @schema Zoi.struct(
            __MODULE__,
            Jido.Seigyo.Schema.fields(
              Jido.Seigyo.SessionConfig.schema(),
              ~w(revision state profile digest model context skills plugins tool_profile execution instructions)a,
              projections: %{
                model: ModelConfig.schema(),
                context: ContextConfig.schema(),
                skills: SkillRef.schema(),
                plugins: PluginRef.schema(),
                tool_profile: ToolProfile.schema(),
                execution: ExecutionConfig.schema()
              }
            )
          )
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema

  @doc false
  def from_data(data) when is_map(data) do
    with {:ok, data} <- Jido.Seigyo.Client.Value.parse(Jido.Seigyo.SessionConfig.schema(), data) do
      from_valid_data(data)
    end
  end

  def from_data(data), do: Jido.Seigyo.Client.Value.invalid(data)

  defp from_valid_data(data) do
    with {:ok, model} <- struct_value(ModelConfig, data["model"]),
         {:ok, context} <- struct_value(ContextConfig, data["context"]),
         {:ok, skills} <- struct_values(SkillRef, data["skills"]),
         {:ok, plugins} <- struct_values(PluginRef, data["plugins"]),
         {:ok, tool_profile} <- struct_value(ToolProfile, data["tool_profile"]),
         {:ok, execution} <- ExecutionConfig.from_data(data["execution"]) do
      Value.parse(@schema, %__MODULE__{
        revision: data["revision"],
        state: data["state"],
        profile: data["profile"],
        digest: data["digest"],
        model: model,
        context: context,
        skills: skills,
        plugins: plugins,
        tool_profile: tool_profile,
        execution: execution,
        instructions: data["instructions"]
      })
    end
  end

  defp struct_value(module, data) when is_map(data) do
    attrs = Map.new(data, fn {key, value} -> {String.to_existing_atom(key), value} end)
    Value.parse(module.schema(), struct!(module, attrs))
  rescue
    _ -> Value.invalid(data)
  end

  defp struct_value(_module, data), do: Value.invalid(data)

  defp struct_values(module, values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case struct_value(module, value) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp struct_values(_module, values), do: Value.invalid(values)
end
