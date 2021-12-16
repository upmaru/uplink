defmodule Uplink.Repo.Migrations.CreateDeploymentEvents do
  use Ecto.Migration

  def change do
    crate table(:deployment_events) do
      add(:name, :string, null: false)
      add(:domain, :string, null: false)
      add(:metadata, :map, default: "{}")
      
      add(
        :deployment_id,
        references(:deployments, on_delete: :restrict),
        null: false
      )
      
      add(
        :actor_id,
        references(:actors, on_delete: :restrict),
        null: false
      )
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:deployment_events, [:deployment_id])
    create index(:deployment_events, [:actor_id])
  end
end
