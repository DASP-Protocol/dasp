# A recorded reply adapter. This example does not connect to a server.
{:ok, client} =
  DASP.Client.new(
    source: "urn:example:client:one",
    host_source: "urn:example:host:one",
    validate_profile: fn
      %{
        "type" => "dasp.command.v1",
        "data" => %{"name" => "counter.add", "input" => %{"amount" => amount} = input}
      } ->
        is_integer(amount) and map_size(input) == 1

      %{"type" => "dasp.receipt.v1"} ->
        true

      _ ->
        false
    end,
    transport: fn wire, _timeout ->
      {:ok, request} = DASP.Wire.decode(wire)

      DASP.Wire.encode(%{
        "specversion" => "1.0",
        "id" => "recorded-receipt",
        "source" => "urn:example:host:one",
        "type" => "dasp.receipt.v1",
        "datacontenttype" => "application/json",
        "requestid" => request["requestid"],
        "data" => %{
          "session_id" => request["data"]["session_id"],
          "command_id" => request["data"]["command_id"],
          "disposition" => "accepted",
          "admission_sequence" => 1,
          "error" => nil
        }
      })
    end
  )

session = %{
  "session_id" => "session-counter",
  "actor_id" => "counter-main",
  "profile" => %{"id" => "urn:example:dasp:counter", "version" => "1"}
}

{:ok, %{"data" => %{"disposition" => "accepted"}}} =
  DASP.Client.submit(client, session, %{
    "command_id" => "command-add-1",
    "name" => "counter.add",
    "input" => %{"amount" => 3}
  })

IO.puts("Recorded receipt: accepted. Completion needs a saved outcome.")
