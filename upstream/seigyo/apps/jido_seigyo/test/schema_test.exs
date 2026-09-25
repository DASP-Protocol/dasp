defmodule Jido.Seigyo.SchemaTest do
  use ExUnit.Case, async: true

  alias Jido.Seigyo.{Receipt, Result, Schema, SessionOpened, Update}

  test "SEIGYO-DEFINITION-003: aliases reuse the canonical byte and ID constraints" do
    fields = Schema.fields(SessionOpened.schema(), [:id], paths: %{id: "session_id"})
    assert {:error, _} = Zoi.parse(fields.id, "bad")
    assert {:ok, _} = Zoi.parse(fields.id, "ses_01994770-1234-7000-8000-000000000001")
    assert_raise KeyError, fn -> Schema.field(SessionOpened.schema(), "missing") end
    assert Map.has_key?(Schema.fields(SessionOpened.schema(), [:workspace_id]), :workspace_id)
  end

  test "SEIGYO-DEFINITION-003: union selection preserves branch limits and nullable projection fields" do
    sequence = Schema.field(Receipt.schema(), "sequence")
    assert {:ok, nil} = Zoi.parse(sequence, nil)
    assert {:ok, 1} = Zoi.parse(sequence, 1)
    assert {:error, _} = Zoi.parse(sequence, 0)
    assert {:error, _} = Zoi.parse(sequence, 9_007_199_254_740_992)

    result_id = Schema.field(Update.schema(), ~w(payload result_id))
    assert {:ok, nil} = Zoi.parse(result_id, nil)
    assert {:error, _} = Zoi.parse(result_id, "bad")

    assert_raise KeyError, fn -> Schema.field(Update.schema(), "missing") end
    assert Schema.field(Receipt.schema(), "version") == Zoi.required(Zoi.literal(1))
  end

  test "SEIGYO-DEFINITION-003: typed collections retain canonical bounds and null alternatives" do
    fields = Schema.fields(Result.schema(), [:blocks], projections: %{blocks: Zoi.string()})
    assert {:ok, ["example"]} = Zoi.parse(fields.blocks, ["example"])
    assert {:error, _} = Zoi.parse(fields.blocks, List.duplicate("example", 51))

    source = Zoi.object(%{"item" => Zoi.object(%{"value" => Zoi.string()}) |> Zoi.nullable()})
    fields = Schema.fields(source, [:item], projections: %{item: Zoi.string()})
    assert {:ok, nil} = Zoi.parse(fields.item, nil)
    assert {:ok, "example"} = Zoi.parse(fields.item, "example")

    fields = Schema.fields(Receipt.schema(), [:error], projections: %{error: Zoi.string()})
    assert {:ok, nil} = Zoi.parse(fields.error, nil)

    for absent <- [Zoi.literal(nil), Zoi.null()] do
      source =
        Zoi.object(%{"child" => Zoi.union([absent, Zoi.object(%{"text" => Zoi.string()})])})

      field = Schema.field(source, ~w(child text))
      assert {:ok, nil} = Zoi.parse(field, nil)
      assert {:ok, "text"} = Zoi.parse(field, "text")
      assert {:error, _} = Zoi.parse(field, 7)
    end
  end
end
