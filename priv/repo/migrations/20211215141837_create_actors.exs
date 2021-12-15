defmodule Uplink.Repo.Migrations.CreateActors do
  use Ecto.Migration

  def change do
    create table(:actors) do
      add :identifier, :string, null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:actors, [:identifier], unique: true)
  end
end
