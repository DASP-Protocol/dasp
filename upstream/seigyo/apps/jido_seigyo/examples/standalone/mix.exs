defmodule SeigyoConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :seigyo_consumer,
      version: "0.1.0",
      elixir: "~> 1.20",
      deps: [
        {:jido_seigyo, path: System.fetch_env!("SEIGYO_PACKAGE_PATH")},
        {:jido_signal, path: System.fetch_env!("SEIGYO_SIGNAL_PATH"), override: true}
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
