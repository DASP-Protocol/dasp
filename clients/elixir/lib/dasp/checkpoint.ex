defmodule DASP.Checkpoint do
  @moduledoc """
  Apply contiguous updates to a saved projection.
  Save the returned state, cursor, and evidence in one transaction before delivery acknowledgment.
  Callbacks must check the selected profile and have no external effects.
  """
  import DASP.Error, only: [fail: 2]
  alias DASP.{Client, Wire}

  @doc "Create a checkpoint from a view whose host context has been authenticated."
  def from_view(view, validate_profile) do
    Wire.protect(fn ->
      event = view |> Wire.encode!() |> Wire.decode!()
      if event["type"] != "dasp.view.v1", do: fail(:checkpoint, "A view is required.")
      Client.profile!(validate_profile, event)
      d = event["data"]

      %{
        "session" => Map.take(d, ["session_id", "actor_id", "profile"]),
        "host_source" => event["source"],
        "cursor" => d["cursor"],
        "state" => d["state"],
        "evidence" => %{}
      }
    end)
  end

  @doc "Return a new checkpoint only if all updates pass validation and the reducer succeeds."
  def apply_updates(checkpoint, events, reduce, validate_profile) do
    Wire.protect(fn ->
      if not is_integer(checkpoint["cursor"]) or checkpoint["cursor"] < 0 or
           checkpoint["cursor"] > 9_007_199_254_740_991,
         do: fail(:checkpoint, "Invalid applied cursor.")

      Enum.reduce(events, checkpoint, fn input, current ->
        event = input |> Wire.encode!() |> Wire.decode!()
        d = event["data"]

        if event["type"] != "dasp.update.v1" or event["source"] != current["host_source"] or
             d["session_id"] != current["session"]["session_id"],
           do: fail(:checkpoint, "Expected an update from the checkpoint session and host.")

        Client.profile!(validate_profile, event)
        sequence = d["sequence"]
        key = Integer.to_string(sequence)
        proof = Map.take(event, ["source", "id", "type", "data", "time", "subject", "dataschema"])

        cond do
          sequence <= current["cursor"] ->
            if not Map.has_key?(current["evidence"], key),
              do:
                fail(:missing_evidence, "Recover a trusted view before handling this old update.")

            if current["evidence"][key] != proof,
              do: fail(:changed_update, "A saved update changed.")

            current

          sequence != current["cursor"] + 1 ->
            fail(:gap, "Read missing updates before advancing the cursor.")

          true ->
            state = reduce.(current["state"], event)

            if not is_map(state) or is_struct(state),
              do: fail(:checkpoint, "Reducer must return a JSON object.")

            DASP.JSON.encode!(state)

            %{
              current
              | "state" => state,
                "cursor" => sequence,
                "evidence" => Map.put(current["evidence"], key, proof)
            }
        end
      end)
    end)
  end
end
