defmodule Uplink.Repo.Migrations.ChangeDeploymentsHashUniqueIndex do
  use Ecto.Migration

  def change do
    drop index(:deployments, [:app_id, :hash], unique: true)
    create index(:deployments, [:app_id, :hash, :channel], unique: true)
  end
end
