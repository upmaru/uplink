defmodule Uplink.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def change do
    Oban.Migrations.up()
  end
end
