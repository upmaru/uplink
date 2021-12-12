defmodule Uplink.MixProject do
  use Mix.Project

  def project do
    [
      app: :uplink,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Uplink.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:ecto, "~> 3.7"},
      {:machinery, "~> 1.0.0"},
      
      {:formation, "~> 0.1.2"},
      
      {:que, "~> 0.10.1"},
      {:memento, "~> 0.3.2"},
      {:plug_cowboy, "~> 2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
