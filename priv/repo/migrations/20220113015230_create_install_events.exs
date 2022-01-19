defmodule Uplink.Repo.Migrations.CreateInstallEvents do
  use Ecto.Migration

  def change do
    create table(:install_events) do
      add(:name, :string, null: false)
      add(:domain, :string, null: false)
      add(:metadata, :map, default: "{}")
      
      add(
        :install_id,
        references(:installs, on_delete: :restrict),
        null: false
      )
      
      add(
        :actor_id,
        references(:actors, on_delete: :restrict),
        null: false
      )
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:install_events, [:install_id])
    create index(:install_events, [:actor_id])
  end
end
