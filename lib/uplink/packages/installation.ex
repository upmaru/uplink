defmodule Uplink.Packages.Installation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "installations" do
    field(:instellar_installation_id, :integer)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(installation, params) do
    installation
    |> cast(params, [:instellar_installation_id])
    |> validate_required([:instellar_installation_id])
  end
end
