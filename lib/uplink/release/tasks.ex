defmodule Uplink.Release.Tasks do
  @app :uplink

  def migrate(options \\ []) do
    config = Application.get_env(:uplink, Uplink.Data) || []
    mode = Keyword.get(config, :mode, "pro")
    force_run = Keyword.get(options, :force)

    if force_run || mode == "pro" do
      Application.ensure_all_started(:ssl)

      for repo <- repos() do
        {:ok, _, _} =
          Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      end
    else
      :ok
    end
  end

  def rollback(repo, version, options \\ []) do
    config = Application.get_env(:uplink, Uplink.Data) || []
    mode = Keyword.get(config, :mode, "pro")
    force_run = Keyword.get(options, :force)

    if force_run || mode == "pro" do
      Application.ensure_all_started(:ssl)

      {:ok, _, _} =
        Ecto.Migrator.with_repo(
          repo,
          &Ecto.Migrator.run(&1, :down, to: version)
        )
    else
      :ok
    end
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
