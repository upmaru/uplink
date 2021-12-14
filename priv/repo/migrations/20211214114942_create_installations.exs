defmodule Uplink.Repo.Migrations.CreateInstallations do
  use Ecto.Migration

  def change do
    create table(:installations) do
      add :instellar_installation_id, :integer, null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:installations, [:instellar_installation_id], unique: true)
  end
end
