defmodule DASP.MixProject do
  use Mix.Project

  def project do
    [
      app: :dasp_ex,
      version: "0.1.0-draft.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Transport-independent clients for DASP draft-01",
      package: [
        files: ~w(lib priv examples mix.exs README.md),
        licenses: [],
        links: %{"GitHub" => "https://github.com/DASP-Protocol/dasp"}
      ],
      deps: [signal_dependency()]
    ]
  end

  def application, do: [extra_applications: [:crypto]]

  # A local V3 checkout can be used for coordinated integration tests.
  # Published consumers use the versioned dependency by default.
  defp signal_dependency do
    case System.get_env("JIDO_SIGNAL_PATH") do
      nil -> {:jido_signal, "~> 3.0.0-beta.4"}
      path -> {:jido_signal, path: Path.expand(path), override: true}
    end
  end
end
