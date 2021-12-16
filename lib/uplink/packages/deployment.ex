defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Installation

  schema "deployments" do
    field :hash, :string
    field :metadata, :map, virtual: true
    field :current_state, :string, default: "created"

    belongs_to :installation, Installation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(deployment, params) do
    deployment
    |> cast(params, [:hash, :metadata])
    |> validate_required([:hash, :metadata])
  end
end
