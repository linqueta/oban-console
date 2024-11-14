defmodule Oban.Console.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :oban_console,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      package: package()
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

  def package do
    [
      name: "oban_console",
      files: ~w(lib .credo.exs .formatter.exs mix.exs README*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/linqueta/oban-console"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_machina, "~> 2.8.0", only: :test},
      {:mimic, "~> 1.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:oban, "~> 2.17", optional: true},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      formatters: ["html"],
      extras: ["README.md"]
    ]
  end
end
