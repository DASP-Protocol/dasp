defmodule Jido.Seigyo.MembershipProtocolTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo

  alias Jido.Seigyo.{
    Catalog,
    CommandAttribution,
    Initialization,
    MemberAdd,
    MemberChanged,
    MemberRemove,
    MemberRoleChange,
    MembershipUpdate,
    MembershipUpdatesPage,
    SessionMember,
    SessionMembers
  }

  @feature "seigyo.membership/1"
  @session_id "ses_018f1a1a-7b3c-7a00-8000-000000000001"
  @command_id "cmd_018f1a1a-7b3c-7a00-8000-000000000002"
  @mutation_id "mut_018f1a1a-7b3c-7a00-8000-000000000003"
  @actor_id "act_018f1a1a-7b3c-7a00-8000-000000000004"
  @other_actor_id "act_018f1a1a-7b3c-7a00-8000-000000000005"
  @member_id "ain_018f1a1a-7b3c-7a00-8000-000000000006"
  @other_member_id "ain_018f1a1a-7b3c-7a00-8000-000000000007"

  defp member(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => @member_id,
        "actor_id" => @actor_id,
        "actor_kind" => "human",
        "display_name" => "Ada",
        "role" => "owner",
        "status" => "active",
        "revision" => 4
      },
      overrides
    )
  end

  defp changed(overrides \\ %{}) do
    Map.merge(
      %{
        "version" => 1,
        "mutation_id" => @mutation_id,
        "session_id" => @session_id,
        "sequence" => 8,
        "previous_revision" => 3,
        "revision" => 4,
        "disposition" => "applied",
        "action" => "added",
        "member" => member()
      },
      overrides
    )
  end

  test "the membership feature is negotiated and leaves the frozen base catalog unchanged" do
    refute "members" in Seigyo.operations()
    refute MemberAdd.type() in Seigyo.request_signal_types()
    refute SessionMembers.type() in Seigyo.result_signal_types()

    assert "members" in Seigyo.operations([@feature])
    assert "member_add" in Seigyo.operations([@feature])
    assert "member_role_change" in Seigyo.operations([@feature])
    assert "member_remove" in Seigyo.operations([@feature])
    assert "command_attribution" in Seigyo.operations([@feature])
    assert MemberAdd.type() in Seigyo.request_signal_types([@feature])
    assert SessionMembers.type() in Seigyo.result_signal_types([@feature])
    assert Seigyo.push_signal_types([@feature]) == Seigyo.push_signal_types()

    assert {:ok, %{name: "member_add"}} = Catalog.operation("member_add", [@feature])
    assert :error = Catalog.operation("member_add")

    assert {:ok, %{signal: MemberAdd, role: :request}} =
             Catalog.message(MemberAdd.type(), [@feature])

    assert :error = Catalog.message(MemberAdd.type())

    assert {:ok, MemberAdd} =
             Catalog.signal_module(MemberAdd.type(), features: [@feature])

    assert :error = Catalog.signal_module(MemberAdd.type())
    assert length(Catalog.signals([@feature])) > length(Catalog.signals())

    capabilities = Seigyo.capabilities("human:ada", [@feature])
    assert capabilities["principal"] == "human:ada"
    assert "members" in capabilities["operations"]

    assert {:ok, selected} =
             Initialization.select(Initialization.membership_offer(), [
               Initialization.coding("human:ada")
             ])

    assert @feature in selected["features"]
    assert "member_add" in selected["capabilities"]["operations"]
  end

  test "member mutations use registered Actor IDs and closed role data" do
    add = %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "actor_id" => @actor_id,
      "role" => "editor",
      "expected_revision" => 3
    }

    assert {:ok, signal} = MemberAdd.new(add)
    assert {:error, _} = Seigyo.validate(signal)
    assert {:ok, ^signal} = Seigyo.validate(signal, features: [@feature])
    assert {:error, _} = MemberAdd.new(%{add | "role" => "agent"})
    assert {:error, _} = MemberAdd.new(Map.put(add, "extra", true))

    role_change = %{
      "version" => 1,
      "mutation_id" => @mutation_id,
      "session_id" => @session_id,
      "member_id" => @member_id,
      "role" => "viewer",
      "expected_revision" => 4
    }

    assert {:ok, _} = MemberRoleChange.new(role_change)
    assert {:error, _} = MemberRoleChange.new(%{role_change | "member_id" => "bad"})

    remove =
      role_change
      |> Map.delete("role")
      |> Map.put("expected_revision", 5)

    assert {:ok, _} = MemberRemove.new(remove)
    assert {:error, _} = MemberRemove.new(Map.put(remove, "role", "viewer"))
  end

  test "member projections include humans and explicit Actor clients but exclude agent roles" do
    actor_member =
      member(%{
        "id" => @other_member_id,
        "actor_id" => @other_actor_id,
        "actor_kind" => "actor",
        "display_name" => "Release actor",
        "role" => "editor"
      })

    assert {:ok, _} = Zoi.parse(SessionMember.schema(), member())
    assert {:ok, _} = Zoi.parse(SessionMember.schema(), actor_member)
    assert {:error, _} = Zoi.parse(SessionMember.schema(), member(%{"role" => "agent"}))
    assert {:error, _} = Zoi.parse(SessionMember.schema(), member(%{"actor_kind" => "subagent"}))
    assert {:error, _} = Zoi.parse(SessionMember.schema(), member(%{"display_name" => ""}))
    assert {:error, _} = Zoi.parse(SessionMember.schema(), member(%{"display_name" => <<0>>}))

    assert {:error, _} =
             Zoi.parse(
               SessionMember.schema(),
               member(%{"display_name" => String.duplicate("x", 81)})
             )

    data = %{
      "version" => 1,
      "session_id" => @session_id,
      "revision" => 4,
      "members" => [member(), actor_member]
    }

    assert {:ok, _} = SessionMembers.new(data)

    assert {:error, _} =
             SessionMembers.new(%{data | "members" => [member(%{"status" => "revoked"})]})

    assert {:error, _} =
             SessionMembers.new(%{data | "members" => [member(), member()]})

    duplicate_actor = %{actor_member | "actor_id" => @actor_id}
    assert {:error, _} = SessionMembers.new(%{data | "members" => [member(), duplicate_actor]})
  end

  test "member mutation results bind action, status, and Session revision" do
    assert {:ok, _} = MemberChanged.new(changed())

    assert {:ok, _} =
             MemberChanged.new(
               changed(%{
                 "action" => "role_changed",
                 "disposition" => "duplicate",
                 "member" => member(%{"role" => "viewer"})
               })
             )

    assert {:ok, _} =
             MemberChanged.new(
               changed(%{"action" => "removed", "member" => member(%{"status" => "revoked"})})
             )

    assert {:error, _} = MemberChanged.new(changed(%{"revision" => 5}))

    assert {:error, _} =
             MemberChanged.new(changed(%{"member" => member(%{"revision" => 3})}))

    assert {:error, _} =
             MemberChanged.new(changed(%{"action" => "removed", "member" => member()}))
  end

  test "Command attribution names a durable member identity" do
    data = %{
      "version" => 1,
      "session_id" => @session_id,
      "command_id" => @command_id,
      "member_id" => @member_id,
      "actor_id" => @actor_id,
      "actor_kind" => "actor",
      "display_name" => "Build actor"
    }

    assert {:ok, signal} = CommandAttribution.new(data)
    assert {:ok, ^signal} = Seigyo.validate(signal, features: [@feature])
    assert {:error, _} = CommandAttribution.new(%{data | "actor_id" => "bad"})
    assert {:error, _} = CommandAttribution.new(%{data | "member_id" => "bad"})
    assert {:error, _} = Seigyo.validate(:not_a_signal, features: [@feature])
  end

  test "membership Updates are available only through the negotiated event schema" do
    data = %{
      "version" => 1,
      "session_id" => @session_id,
      "kind" => "event",
      "sequence" => 9,
      "event_type" => "member_added",
      "command_id" => nil,
      "payload" => %{
        "mutation_id" => @mutation_id,
        "previous_revision" => 3,
        "member" => member()
      }
    }

    assert {:ok, update} = MembershipUpdate.new(data)
    assert {:error, _} = Jido.Seigyo.Update.new(data)
    assert {:error, _} = Seigyo.validate(update)
    assert {:ok, ^update} = Seigyo.validate(update, features: [@feature])

    assert {:ok, page} =
             MembershipUpdatesPage.new(%{
               "version" => 1,
               "session_id" => @session_id,
               "after_sequence" => 8,
               "updates" => [data],
               "next_cursor" => nil
             })

    assert {:ok, ^page} = Seigyo.validate(page, features: [@feature])
    assert {:error, _} = Jido.Seigyo.UpdatesPage.new(page.data)
    assert "member_added" in Seigyo.update_event_types([@feature])
    refute "member_added" in Seigyo.update_event_types()

    assert {:ok, client_update} = Jido.Seigyo.Client.Update.from_data(data)
    assert client_update.member.actor_kind == "human"
    assert Jido.Seigyo.Client.Update.to_data(client_update) == data
  end
end
