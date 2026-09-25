defmodule Jido.Seigyo.Initialization do
  @moduledoc """
  Bounded initialization and saved contract requirements, independent of a runtime.

  Static descriptors are server configuration. They are not protocol resources.
  Feature selection never grants access to a Session or a resource.
  """

  alias Jido.Seigyo.{Bundle, Contract, Error, Release}

  @core "seigyo.core/1"
  @progress "seigyo.progress/1"
  @membership "seigyo.membership/1"
  @features [@core, @membership, @progress]
  @offer_keys ~w(optional_features profile required_features versions)
  @selection_keys ~w(capabilities features limits profile version)
  @descriptor_keys ~w(capabilities digest features id limits protocol_versions required_features version)
  @max_offer_bytes 8192
  @core_limits ~w(websocket_frame_bytes signal_json_bytes request_ref_bytes json_integer_max page_items updates_page_json_bytes)

  @doc "Machine-readable bootstrap schemas. Custom rules remain normative in initialization.md."
  def schemas do
    positive = %{"type" => "integer", "minimum" => 1, "maximum" => Contract.max_json_integer()}

    versions = %{
      "type" => "array",
      "items" => positive,
      "minItems" => 1,
      "maxItems" => 8,
      "uniqueItems" => true
    }

    name = %{"type" => "string", "pattern" => "^[a-z][a-z0-9_]*$", "maxLength" => 64}

    features = %{
      "type" => "array",
      "maxItems" => 32,
      "uniqueItems" => true,
      "items" => %{
        "type" => "string",
        "maxLength" => 64,
        "pattern" => "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+/[1-9][0-9]*$"
      }
    }

    identity =
      closed(%{
        "id" => name,
        "version" => positive,
        "digest" => %{"type" => "string", "pattern" => "^[0-9a-f]{64}$"}
      })

    strings = %{
      "type" => "array",
      "items" => %{"type" => "string"},
      "maxItems" => 64,
      "uniqueItems" => true
    }

    caps =
      closed(
        Map.merge(
          Map.new(
            ~w(operations controls request_signal_types result_signal_types push_signal_types update_event_types),
            &{&1, strings}
          ),
          %{
            "version" => positive,
            "profile" => name,
            "principal" => %{"type" => "string", "minLength" => 1, "maxLength" => 256}
          }
        )
      )

    limits =
      Release.manifest()["limits"]
      |> Map.new(fn {key, max} -> {key, Map.put(positive, "maximum", max)} end)
      |> closed()
      |> Map.put("required", @core_limits)

    %{
      "offer" =>
        closed(%{
          "versions" => versions,
          "profile" => closed(%{"id" => name, "versions" => versions}),
          "required_features" => features,
          "optional_features" => features
        })
        |> Map.put("x-seigyo-maxJsonBytes", @max_offer_bytes),
      "selection" =>
        closed(%{
          "version" => %{"const" => 1},
          "profile" => identity,
          "features" => features,
          "limits" => limits,
          "capabilities" => caps
        }),
      "saved_requirements" =>
        closed(%{
          "protocol_version" => positive,
          "profile" => identity,
          "required_features" => features
        })
    }
  end

  defp closed(properties),
    do: %{
      "type" => "object",
      "properties" => properties,
      "required" => properties |> Map.keys() |> Enum.sort(),
      "additionalProperties" => false
    }

  @doc "The default offer for an opt-in coding v1 client."
  def offer do
    %{
      "versions" => [1],
      "profile" => %{"id" => "coding", "versions" => [1]},
      "required_features" => [@core],
      "optional_features" => [@progress]
    }
  end

  @doc "An opt-in offer for the Session membership extension."
  def membership_offer do
    offer()
    |> Map.update!("required_features", &Enum.sort([@membership | &1]))
  end

  @doc "The static coding profile, with safe capabilities for this connection."
  def coding(principal) do
    %{
      "id" => "coding",
      "version" => 1,
      "digest" => Bundle.contract()["digest"],
      "protocol_versions" => [1],
      "required_features" => [@core],
      "features" => @features,
      "capabilities" => Jido.Seigyo.capabilities(principal, [@membership]),
      "limits" => Release.manifest()["limits"]
    }
  end

  @doc "Checks the bootstrap offer before a protocol version is selected."
  def validate_offer(value) do
    with :ok <- exact(value, @offer_keys, "initialization"),
         :ok <- bounded_json(value, @max_offer_bytes),
         :ok <- check(versions?(value["versions"]), "versions"),
         :ok <- exact(value["profile"], ~w(id versions), "profile"),
         :ok <- check(profile_name?(value["profile"]["id"]), "profile"),
         :ok <- check(versions?(value["profile"]["versions"]), "profile"),
         :ok <- check(features?(value["required_features"]), "required_features"),
         :ok <- check(features?(value["optional_features"]), "optional_features"),
         :ok <-
           check(
             disjoint?(value["required_features"], value["optional_features"]),
             "optional_features"
           ),
         do: :ok
  end

  @doc "Selects the highest common protocol version, then the highest profile version."
  def select(offer, profiles) do
    with :ok <- validate_offer(offer),
         :ok <- descriptors(profiles),
         {:ok, version} <- protocol_version(offer, profiles),
         {:ok, profile} <- profile(offer, profiles, version),
         {:ok, features} <- select_features(offer, profile) do
      {:ok,
       %{
         "version" => version,
         "profile" => identity(profile),
         "features" => features,
         "limits" => profile["limits"],
         "capabilities" => capabilities(profile["capabilities"], features)
       }}
    end
  end

  @doc "Checks a selection against an offer and the implemented bootstrap version."
  def validate_selection(offer, selected) do
    with :ok <- validate_offer(offer),
         :ok <- exact(selected, @selection_keys, "initialization"),
         :ok <- check(selected["version"] == 1 and 1 in offer["versions"], "versions"),
         :ok <- exact(selected["profile"], ~w(digest id version), "profile"),
         :ok <- check(selected["profile"]["id"] == offer["profile"]["id"], "profile"),
         :ok <- check(selected["profile"]["version"] in offer["profile"]["versions"], "profile"),
         :ok <- check(digest?(selected["profile"]["digest"]), "profile"),
         :ok <- check(features?(selected["features"]), "features"),
         :ok <-
           check(
             subset?(
               selected["features"],
               offer["required_features"] ++ offer["optional_features"]
             ),
             "features"
           ),
         :ok <-
           check(
             subset?([@core | offer["required_features"]], selected["features"]),
             "required_features"
           ),
         :ok <- limits(selected["limits"]),
         :ok <-
           capability_identity(
             selected["capabilities"],
             selected["profile"]["id"],
             selected["version"]
           ),
         do: :ok
  end

  @doc "Validates saved requirements without assuming that this reader supports them."
  def validate_requirements(value) do
    with :ok <- exact(value, ~w(profile protocol_version required_features), "protocol_contract"),
         :ok <- check(positive?(value["protocol_version"]), "protocol_version"),
         :ok <- exact(value["profile"], ~w(digest id version), "profile"),
         :ok <- check(profile_name?(value["profile"]["id"]), "profile"),
         :ok <- check(positive?(value["profile"]["version"]), "profile"),
         :ok <- check(digest?(value["profile"]["digest"]), "profile"),
         :ok <- check(features?(value["required_features"]), "required_features"),
         do: :ok
  end

  @doc false
  def check_requirements(value, _opts) do
    case validate_requirements(value) do
      :ok ->
        :ok

      {:error, error} ->
        {:error,
         Zoi.Error.custom_error(
           issue: {"invalid saved contract", [jido_code: error.code, field: error.field]}
         )}
    end
  end

  @doc "The immutable requirements saved with a Session."
  def requirements(profile) do
    %{
      "protocol_version" => 1,
      "profile" => identity(profile),
      "required_features" => Enum.sort(profile["required_features"])
    }
  end

  @doc "The saved contract for existing coding v1 Sessions."
  def legacy_requirements, do: requirements(coding("local-user"))

  @doc "Legacy clients support the complete frozen coding v1 profile."
  def legacy_selection(principal) do
    {:ok, selected} = select(offer(), [coding(principal)])
    selected
  end

  @doc "Checks saved requirements after the caller has been authorized."
  def readable(saved, selected) do
    cond do
      saved["protocol_version"] != selected["version"] ->
        {:error, Error.new("unsupported_version", "protocol_version")}

      saved["profile"] != selected["profile"] ->
        {:error, Error.new("conflict", "profile")}

      not subset?(saved["required_features"], selected["features"]) ->
        {:error, Error.new("invalid_field", "required_features")}

      true ->
        :ok
    end
  end

  defp descriptors(profiles) when is_list(profiles) and length(profiles) in 1..32 do
    with :ok <-
           Enum.reduce_while(profiles, :ok, fn profile, :ok ->
             case descriptor(profile) do
               :ok -> {:cont, :ok}
               error -> {:halt, error}
             end
           end) do
      identities = Enum.map(profiles, &{&1["id"], &1["version"]})

      if Enum.uniq(identities) == identities,
        do: :ok,
        else: {:error, Error.new("conflict", "profile")}
    end
  end

  defp descriptors(_), do: invalid("profile")

  defp descriptor(profile) do
    with :ok <- exact(profile, @descriptor_keys, "profile"),
         :ok <- check(profile_name?(profile["id"]), "profile"),
         :ok <- check(positive?(profile["version"]), "profile"),
         :ok <- check(digest?(profile["digest"]), "profile"),
         :ok <- check(versions?(profile["protocol_versions"]), "versions"),
         :ok <- check(features?(profile["features"]), "features"),
         :ok <- check(features?(profile["required_features"]), "required_features"),
         :ok <-
           check(
             @core in profile["required_features"] and
               subset?(profile["required_features"], profile["features"]),
             "required_features"
           ),
         :ok <-
           check(
             Enum.all?(
               profile["features"],
               &(not String.starts_with?(&1, "seigyo.") or &1 in @features)
             ),
             "features"
           ),
         :ok <- limits(profile["limits"]),
         :ok <- capability_identity(profile["capabilities"], profile["id"], 1),
         do: :ok
  end

  defp protocol_version(offer, profiles) do
    common =
      Enum.filter(offer["versions"], fn version ->
        # Bootstrap v1 is the only implemented protocol, regardless of descriptors.
        version == 1 and Enum.any?(profiles, &(version in &1["protocol_versions"]))
      end)

    case common do
      [] -> {:error, Error.new("unsupported_version", "versions")}
      values -> {:ok, Enum.max(values)}
    end
  end

  defp profile(offer, profiles, version) do
    profiles
    |> Enum.filter(
      &(&1["id"] == offer["profile"]["id"] and
          &1["version"] in offer["profile"]["versions"] and version in &1["protocol_versions"])
    )
    |> Enum.max_by(& &1["version"], fn -> nil end)
    |> case do
      nil -> invalid("profile")
      profile -> {:ok, profile}
    end
  end

  defp select_features(offer, profile) do
    offered = offer["required_features"] ++ offer["optional_features"]
    selected = Enum.filter(offered, &(&1 in profile["features"])) |> Enum.sort()

    if subset?(offer["required_features"] ++ profile["required_features"], selected),
      do: {:ok, selected},
      else: invalid("required_features")
  end

  defp capabilities(capabilities, features) do
    capabilities =
      if capabilities["profile"] == "coding" do
        Jido.Seigyo.capabilities(capabilities["principal"], features)
      else
        capabilities
      end

    if @progress in features,
      do: capabilities,
      else:
        capabilities
        |> Map.update!("controls", &List.delete(&1, "watch_progress"))
        |> Map.update!("push_signal_types", &List.delete(&1, "jido.client.v1.progress"))
  end

  defp identity(profile), do: Map.take(profile, ~w(digest id version))

  defp limits(value) do
    maxima = Release.manifest()["limits"]

    with :ok <- check(is_map(value), "limits"),
         :ok <-
           check(
             subset?(@core_limits, Map.keys(value)) and subset?(Map.keys(value), Map.keys(maxima)),
             "limits"
           ) do
      check(
        Enum.all?(value, fn {key, count} -> positive?(count) and count <= maxima[key] end),
        "limits"
      )
    end
  end

  defp capability_identity(%{"profile" => id, "version" => version} = caps, id, version) do
    check(is_list(caps["controls"]) and is_list(caps["push_signal_types"]), "capabilities")
  end

  defp capability_identity(_, _, _), do: invalid("capabilities")

  defp exact(map, keys, field) when is_map(map),
    do: check(Enum.sort(Map.keys(map)) == Enum.sort(keys), field)

  defp exact(_, _, field), do: invalid(field)
  defp check(true, _), do: :ok
  defp check(false, field), do: invalid(field)
  defp invalid(field), do: {:error, Error.new("invalid_field", field)}

  defp positive?(v), do: is_integer(v) and v > 0 and v <= Contract.max_json_integer()

  defp versions?(v),
    do: is_list(v) and length(v) in 1..8 and Enum.uniq(v) == v and Enum.all?(v, &positive?/1)

  defp features?(v),
    do: is_list(v) and length(v) <= 32 and Enum.uniq(v) == v and Enum.all?(v, &feature?/1)

  defp feature?(v),
    do:
      is_binary(v) and byte_size(v) <= 64 and
        Regex.match?(~r/\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\/[1-9][0-9]*\z/, v)

  defp profile_name?(v),
    do: is_binary(v) and byte_size(v) in 1..64 and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, v)

  defp digest?(v), do: is_binary(v) and Regex.match?(~r/\A[0-9a-f]{64}\z/, v)
  defp subset?(xs, ys), do: Enum.all?(xs, &(&1 in ys))
  defp disjoint?(xs, ys), do: not Enum.any?(xs, &(&1 in ys))

  defp bounded_json(value, limit) do
    case Jason.encode(value) do
      {:ok, bytes} when byte_size(bytes) <= limit -> :ok
      _ -> {:error, Error.new("too_large", "initialization")}
    end
  end
end
