defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Installation

  schema "deployments" do
    field(:hash, :string)
    field(:current_state, :string, default: "created")

    belongs_to(:installation, Installation)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(deployment, params) do
    deployment
    |> cast(params, [:hash])
    |> validate_required([:hash])
  end
end
