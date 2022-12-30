defmodule Uplink.Repo.Migrations.AddProviderToActors do
  use Ecto.Migration

  def change do
    alter table(:actors) do
      add :provider, :string, default: "instellar"
    end
  end
end
