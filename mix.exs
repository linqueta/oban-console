defmodule Oban.Console.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_console,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_machina, "~> 2.8.0", only: :test},
      {:mimic, "~> 1.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:oban, "~> 2.17", optional: true},
      {:jason, "~> 1.4"}
    ]
  end
end
