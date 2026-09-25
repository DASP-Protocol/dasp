# Run with this consumer's ebin directories, without umbrella server paths.
alias Jido.Seigyo.{Client, Initialization}

{:ok, _} = Application.ensure_all_started(:jido_seigyo)

for module <- [Jido.Code.Server, Jido.Code.Web.Endpoint, Jido.AI, Jido.AgentServer] do
  if Code.ensure_loaded?(module), do: raise("consumer loaded server code")
end

{:ok, client} =
  Client.start_link(
    url: System.fetch_env!("SEIGYO_URL"),
    token: System.fetch_env!("SEIGYO_TOKEN"),
    initialization: Initialization.offer()
  )

{:ok, session} = Client.open(client)

{:ok, receipt} =
  Client.submit_text(client, session, "Reply briefly to confirm this protocol test.")

:ok = Client.disconnect(client)

{:ok, client} =
  Client.start_link(
    url: System.fetch_env!("SEIGYO_URL"),
    token: System.fetch_env!("SEIGYO_TOKEN")
  )

{:ok, ^session} = Client.open(client, session)

{:ok, duplicate} =
  Client.submit_text(client, session, "Reply briefly to confirm this protocol test.",
    command_id: receipt.command_id
  )

true = duplicate.disposition == "duplicate" and duplicate.sequence == receipt.sequence

deadline = System.monotonic_time(:millisecond) + 30_000

wait = fn wait ->
  case Client.result(client, session, receipt) do
    {:ok, result} ->
      result

    {:error, %{code: "unavailable", field: "result"}} ->
      if System.monotonic_time(:millisecond) >= deadline, do: raise("Result deadline")
      Process.sleep(20)
      wait.(wait)

    _ ->
      raise "Result read failed"
  end
end

result = wait.(wait)
true = result.status == "completed"
{:ok, %{updates: [admission, terminal]}} = Client.updates(client, session)
true = admission.sequence == receipt.sequence
true = terminal.result_id == result.result_id
{:ok, ^result} = Client.result(client, session, receipt)
:ok = Client.disconnect(client)
IO.puts("SEIGYO_STANDALONE_OK")
