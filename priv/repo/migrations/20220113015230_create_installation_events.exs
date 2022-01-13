defmodule Uplink.Repo.Migrations.CreateInstallationEvents do
  use Ecto.Migration

  def change do
    create table(:installation_events) do
      add(:name, :string, null: false)
      add(:domain, :string, null: false)
      add(:metadata, :map, default: "{}")
      
      add(
        :installation_id,
        references(:installations, on_delete: :restrict),
        null: false
      )
      
      add(
        :actor_id,
        references(:actors, on_delete: :restrict),
        null: false
      )
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:installation_events, [:installation_id])
    create index(:installation_events, [:actor_id])
  end
end
