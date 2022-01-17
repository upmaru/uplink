defmodule Uplink.Repo.Migrations.CreateInstallations do
  use Ecto.Migration

  def change do
    create table(:installations) do
      add :instellar_installation_id, :integer, null: false
      add :current_state, :citext, default: "created"
      
      add :deployment_id, references(:deployments, on_delete: :restrict), null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:installations, [:deployment_id, :instellar_installation_id], unique: true)
  end
end
