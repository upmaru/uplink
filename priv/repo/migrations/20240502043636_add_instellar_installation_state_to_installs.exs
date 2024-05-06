defmodule Uplink.Repo.Migrations.AddInstellarInstallationStateToInstalls do
  use Ecto.Migration

  def change do
    alter table(:installs) do
      add :instellar_installation_state, :citext, default: "active"
    end

    create index(:installs, [:instellar_installation_state])
  end
end
