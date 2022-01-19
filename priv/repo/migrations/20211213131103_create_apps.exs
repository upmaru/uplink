defmodule Uplink.Repo.Migrations.CreateApps do
  use Ecto.Migration

  def change do
    create table(:apps) do
      add :slug, :citext, null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    create index(:apps, [:slug], unique: true)
  end
end
