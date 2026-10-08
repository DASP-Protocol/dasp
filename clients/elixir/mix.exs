defmodule DASP.MixProject do
  use Mix.Project

  def project do
    [
      app: :dasp_ex,
      version: "0.1.0-draft.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r/test\/support\//],
      description: "DASP draft-01 client with Jido signals and Mint WebSocket",
      package: [
        files: ~w(lib priv examples mix.exs README.md),
        licenses: [],
        links: %{"GitHub" => "https://github.com/DASP-Protocol/dasp"}
      ],
      deps: [
        signal_dep(),
        {:mint_web_socket, "~> 1.0.6"}
      ]
    ]
  end

  defp signal_dep do
    sibling = Path.expand("../../../jido_signal", __DIR__)

    path =
      System.get_env("DASP_SIGNAL_PATH") ||
        if Mix.env() in [:dev, :test] and File.regular?(Path.join(sibling, "mix.exs")),
          do: sibling

    if path do
      {:jido_signal, path: Path.expand(path), override: true}
    else
      {:jido_signal, "~> 3.0.0-beta.4"}
    end
  end

  def application, do: [extra_applications: [:crypto, :ssl, :public_key]]
end
