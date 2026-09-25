# Run from jido_seigyo: mix run --no-start scripts/export_contract.exs DESTINATION
alias Jido.Seigyo.Bundle

[destination] = System.argv()
:ok = Bundle.verify(Bundle.contract(), Bundle.files())

files =
  Bundle.files()
  |> Map.put("contract.json", Jason.encode!(Bundle.descriptor(Bundle.files()), pretty: true) <> "\n")

# Check every destination before any write. An existing release is immutable.
Enum.each(files, fn {name, expected} ->
  path = Path.join(destination, name)

  case File.read(path) do
    {:ok, ^expected} -> :ok
    {:error, :enoent} -> :ok
    _ -> raise "refuse to replace released file: #{path}"
  end
end)

Enum.each(files, fn {name, bytes} ->
  path = Path.join(destination, name)
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, bytes)
end)

IO.puts(Bundle.contract()["digest"])
