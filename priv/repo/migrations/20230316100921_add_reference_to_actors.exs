defmodule Uplink.Repo.Migrations.AddReferenceToActors do
  use Ecto.Migration

  def change do
    alter table(:actors) do
      add :reference, :string

      modify :provider, :string, null: false
    end

    create index(:actors, [:reference])
    create unique_index(:actors, [:provider, :reference])

    drop unique_index(:actors, [:identifier])
    create unique_index(:actors, [:provider, :identifier])
  end
end
