defmodule Jido.Seigyo.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_seigyo,
      version: "0.1.0-dev",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      # Keep the normative protocol kernel at 100%. The client is part of
      # this application but has its own transport-focused test surface.
      test_coverage: [
        summary: [threshold: 100],
        ignore_modules: [~r/^Jido\.Seigyo\.Client/]
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jido_signal, path: "../../../jido_signal", override: true},
      {:jason, "~> 1.4"},
      {:splode, "~> 0.3.0"},
      {:websockex, "~> 0.5.1"},
      {:zoi, "~> 0.18.1"}
    ]
  end
end
