defmodule Uplink.Packages.Installation do
  use Ecto.Schema
  import Ecto.Changeset

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "installations" do
    field :instellar_installation_id, :integer
    field :current_state, :string, default: "synced"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(installation, params) do
    installation
    |> cast(params, [:instellar_installation_id])
    |> validate_required([:instellar_installation_id])
  end
end
