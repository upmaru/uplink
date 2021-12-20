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

      # Data
      {:ecto_sql, "~> 3.7.1"},
      {:postgrex, ">= 0.0.0"},
      {:eventful, "~> 0.2.3"},

      # Caching Layer
      {:nebulex, "~> 2.3"},
      {:shards, "~> 1.0"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},

      # Worker
      {:oban, "~> 2.10"},

      # Infrastructure
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},
      {:formation, "~> 0.1.2"},
      {:plug_cowboy, "~> 2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
