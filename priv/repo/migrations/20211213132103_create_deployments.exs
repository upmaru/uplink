defmodule Uplink.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :current_state, :string, default: "created"
      add :instellar_installation_id, :integer
      
      timestamps(type: :utc_datetime_usec)
    end
  end
end
