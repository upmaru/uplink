defmodule Uplink.Repo.Migrations.CreateArchives do
  use Ecto.Migration

  def change do
    create table(:archives) do
      add :node, :string, null: false
      add :locations, {:array, :string}, null: false
      add :current_state, :citext, defaut: "created", null: false
      
      add :deployment_id, references(:deployments, on_delete: :restrict), null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:archives, [:deployment_id], unique: true)
  end
end
