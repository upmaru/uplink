defmodule Uplink.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :hash, :string, null: false
      add :current_state, :citext, default: "created"
      add :installation_id, references(:installations, on_delete: :restrict), null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:deployments, [:installation_id])
  end
end
