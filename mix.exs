defmodule Uplink.MixProject do
  use Mix.Project

  def project do
    [
      app: :uplink,
      version: "0.10.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        uplink: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/scenarios", "test/fixtures"]

  defp elixirc_paths(_), do: ["lib"]

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
      {:ecto_sql, "~> 3.9"},
      {:postgrex, ">= 0.0.0"},
      {:eventful, "~> 0.2.3"},

      # Caching Layer
      {:nebulex, "~> 2.3"},
      {:shards, "~> 1.0"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.0"},

      # Worker
      {:oban, "~> 2.14"},

      # Rest Client
      {:req, "~> 0.4"},

      # Clustering
      {:libcluster, "~> 3.0"},

      # Downstream
      {:downstream, "~> 1.1.0"},

      # One time password
      {:pot, "~> 1.0.2"},

      # Certificate
      {:x509, "~> 0.8.4"},

      # Infrastructure
      {:formation, "~> 0.13"},
      {:lexdee, "~> 2.3"},
      {:plug_cowboy, "~> 2.0"},
      {:reverse_proxy_plug, "~> 2.1"},
      {:mint_web_socket, "~> 1.0.2"},

      # Test
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  def aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end
end
