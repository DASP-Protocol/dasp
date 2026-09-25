defmodule DASP.Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :dasp_client,
      version: "0.1.0-draft.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Transport-independent clients for DASP draft-01",
      package: [
        files: ~w(lib priv examples mix.exs README.md),
        licenses: [],
        links: %{"GitHub" => "https://github.com/DASP-Protocol/dasp"}
      ],
      deps: [{:jason, "~> 1.4"}, {:jsv, "~> 0.25.0"}, {:decimal, "~> 3.0"}]
    ]
  end

  def application, do: [extra_applications: [:crypto]]
end
