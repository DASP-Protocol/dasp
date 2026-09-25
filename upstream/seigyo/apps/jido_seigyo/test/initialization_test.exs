defmodule Jido.Seigyo.InitializationTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.{Bundle, Initialization}

  defp offer(changes \\ %{}) do
    Map.merge(
      %{
        "versions" => [2, 1],
        "profile" => %{"id" => "coding", "versions" => [2, 1]},
        "required_features" => ["seigyo.core/1"],
        "optional_features" => ["example.future/1", "seigyo.progress/1"]
      },
      changes
    )
  end

  test "SEIGYO-INIT-001: selection is deterministic and excludes unknown optional features" do
    profile = Initialization.coding("alice")
    assert {:ok, selected} = Initialization.select(offer(), [profile])
    assert selected["version"] == 1

    assert selected["profile"] == %{
             "id" => "coding",
             "version" => 1,
             "digest" => Bundle.contract()["digest"]
           }

    assert selected["features"] == ["seigyo.core/1", "seigyo.progress/1"]
    assert selected["capabilities"]["principal"] == "alice"
    assert selected["limits"]["websocket_frame_bytes"] == 524_288
    assert :ok = Initialization.validate_selection(offer(), selected)
  end

  test "SEIGYO-INIT-002: no common version and unsupported requirements have bounded errors" do
    profiles = [Initialization.coding("alice")]

    assert {:error, %{code: "unsupported_version", field: "versions"}} =
             Initialization.select(offer(%{"versions" => [2]}), profiles)

    assert {:error, %{code: "invalid_field", field: "profile"}} =
             Initialization.select(
               offer(%{"profile" => %{"id" => "echo", "versions" => [1]}}),
               profiles
             )

    assert {:error, %{field: "required_features"}} =
             Initialization.select(
               offer(%{"required_features" => ["example.required/1"]}),
               profiles
             )

    assert {:error, %{field: "required_features"}} =
             Initialization.select(
               offer(%{"required_features" => [], "optional_features" => []}),
               profiles
             )
  end

  test "SEIGYO-INIT-003: bootstrap values have closed shapes and finite limits" do
    invalid = [
      nil,
      [],
      %{},
      Map.put(offer(), "extra", true),
      offer(%{"versions" => [1, 1]}),
      offer(%{"versions" => []}),
      offer(%{"versions" => Enum.to_list(1..9)}),
      offer(%{"versions" => [true]}),
      offer(%{"versions" => [9_007_199_254_740_992]}),
      offer(%{"profile" => %{"id" => "coding", "versions" => [1], "extra" => nil}}),
      offer(%{"required_features" => ["core"]}),
      offer(%{"required_features" => ["seigyo.core/0"]}),
      offer(%{"optional_features" => ["seigyo.core/1"]}),
      offer(%{"optional_features" => ["example." <> String.duplicate("x", 60) <> "/1"]}),
      offer(%{"optional_features" => Enum.map(1..33, &"example.feature/#{&1}")})
    ]

    for value <- invalid, do: assert({:error, _} = Initialization.validate_offer(value))
    assert :ok = Initialization.validate_offer(offer())
  end

  test "SEIGYO-INIT-004: progress is selected only when offered" do
    assert {:ok, selected} =
             Initialization.select(offer(%{"optional_features" => []}), [
               Initialization.coding("alice")
             ])

    assert selected["features"] == ["seigyo.core/1"]
    refute "watch_progress" in selected["capabilities"]["controls"]
    refute "jido.client.v1.progress" in selected["capabilities"]["push_signal_types"]
  end

  test "SEIGYO-INIT-005: profile descriptors are static and collisions fail" do
    coding = Initialization.coding("alice")

    assert {:error, %{code: "conflict", field: "profile"}} =
             Initialization.select(offer(), [coding, coding])

    invalid = Map.put(coding, "features", ["seigyo.core/1", "seigyo.unassigned/1"])
    assert {:error, %{field: "features"}} = Initialization.select(offer(), [invalid])
    echo = coding |> Map.put("id", "echo") |> Map.put("digest", String.duplicate("a", 64))
    echo = put_in(echo, ["capabilities", "profile"], "echo")
    request = offer(%{"profile" => %{"id" => "echo", "versions" => [1]}})

    assert {:ok, %{"profile" => %{"id" => "echo"}}} =
             Initialization.select(request, [coding, echo])
  end

  test "SEIGYO-INIT-006: a client rejects unoffered or malformed selections" do
    assert {:ok, selected} = Initialization.select(offer(), [Initialization.coding("alice")])

    invalid = [
      nil,
      Map.put(selected, "extra", nil),
      Map.put(selected, "version", 2),
      Map.put(selected, "features", ["seigyo.core/1", "example.unoffered/1"]),
      Map.put(selected, "features", []),
      put_in(selected, ["profile", "digest"], "bad"),
      put_in(selected, ["profile", "id"], "other"),
      put_in(selected, ["limits", "websocket_frame_bytes"], 0),
      put_in(selected, ["capabilities", "profile"], "other")
    ]

    for value <- invalid,
        do: assert({:error, _} = Initialization.validate_selection(offer(), value))
  end

  test "SEIGYO-INIT-007: saved requirements exclude transient settings and cannot be downgraded" do
    profile = Initialization.coding("alice")
    saved = Initialization.requirements(profile)
    assert Map.keys(saved) |> Enum.sort() == ~w(profile protocol_version required_features)
    assert {:ok, selected} = Initialization.select(offer(), [profile])
    assert :ok = Initialization.readable(saved, selected)

    assert {:error, %{field: "required_features"}} =
             Initialization.readable(
               Map.put(saved, "required_features", ["example.future/1"]),
               selected
             )

    assert {:error, %{field: "profile"}} =
             Initialization.readable(
               put_in(saved, ["profile", "digest"], String.duplicate("b", 64)),
               selected
             )

    assert {:error, %{code: "unsupported_version"}} =
             Initialization.readable(Map.put(saved, "protocol_version", 2), selected)
  end

  test "SEIGYO-INIT-003/007: saved values and bootstrap failures remain bounded" do
    saved = Initialization.legacy_requirements()
    assert :ok = Initialization.validate_requirements(saved)
    assert :ok = Initialization.check_requirements(saved, [])

    assert {:error, _} =
             Initialization.check_requirements(Map.put(saved, "credentials", "secret"), [])

    assert :ok = Initialization.readable(saved, Initialization.legacy_selection("alice"))

    for profiles <- [nil, [], List.duplicate(Initialization.coding("alice"), 33)] do
      assert {:error, %{field: "profile"}} = Initialization.select(offer(), profiles)
    end

    invalid = Map.put(Initialization.coding("alice"), "required_features", [])
    assert {:error, %{field: "required_features"}} = Initialization.select(offer(), [invalid])
    oversized = offer(%{"profile" => %{"id" => String.duplicate("x", 8192), "versions" => [1]}})
    assert {:error, %{code: "too_large"}} = Initialization.validate_offer(oversized)
  end

  test "SEIGYO-INIT-001: the published bootstrap schemas match their source" do
    path = Application.app_dir(:jido_seigyo, "priv/seigyo/initialization-v1/schemas.json")
    assert path |> File.read!() |> Jason.decode!() == Initialization.schemas()
    assert Initialization.schemas()["offer"]["additionalProperties"] == false
    assert Initialization.schemas()["offer"]["x-seigyo-maxJsonBytes"] == 8192
  end
end
