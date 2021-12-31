defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Installation

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "deployments" do
    field :hash, :string
    field :current_state, :string, default: "created"

    field :metadata, :map, virtual: true

    belongs_to :installation, Installation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(deployment, params) do
    deployment
    |> cast(params, [:hash, :metadata])
    |> validate_required([:hash])
  end

  def identifier(%__MODULE__{hash: hash, metadata: metadata}) do
    Path.join([
      ~s(deployments),
      metadata.organization.slug,
      metadata.package.slug,
      hash
    ])
  end
end
