defmodule Uplink.Repo.Migrations.ChangeDeploymentArchiveUrl do
  use Ecto.Migration

  def change do
    alter table(:deployments) do
      modify :archive_url, :text, null: false
    end
  end
end
