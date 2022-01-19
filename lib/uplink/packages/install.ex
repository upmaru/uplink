defmodule Uplink.Packages.Install do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Deployment

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "installs" do
    field :instellar_installation_id, :integer
    field :current_state, :string, default: "created"

    belongs_to :deployment, Deployment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(install, params) do
    install
    |> cast(params, [:instellar_installation_id])
    |> validate_required([:instellar_installation_id])
  end
end
