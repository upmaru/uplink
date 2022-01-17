defmodule Uplink.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :hash, :string, null: false
      add :archive_url, :string, null: false
      add :current_state, :citext, default: "created"
      
      add :app_id, references(:apps, on_delete: :restrict), null: false
            
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:deployments, [:app_id])
    create index(:deployments, [:app_id, :hash], unique: true)
  end
end
