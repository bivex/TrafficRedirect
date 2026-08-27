defmodule TrafficRedirect.MixProject do
  use Mix.Project

  def project do
    [
      app: :traffic_redirect,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TrafficRedirect.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.16"},
      {:jason, "~> 1.4"},
      {:finch, "~> 0.19"},
      {:telemetry, "~> 1.2"},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
