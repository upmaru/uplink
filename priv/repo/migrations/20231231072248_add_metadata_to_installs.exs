defmodule Uplink.Repo.Migrations.AddMetadataToInstalls do
  use Ecto.Migration

  def change do
    alter table(:installs) do
      add :metadata_snapshot, :map, null: false, default: %{}
    end
  end
end
