defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.{
    Installation,
    Archive
  }

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "deployments" do
    field :hash, :string
    field :archive_url, :string
    field :current_state, :string, default: "created"

    field :metadata, :map, virtual: true

    belongs_to :installation, Installation

    has_one :archive, Archive

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(deployment, params) do
    deployment
    |> cast(params, [:hash, :archive_url, :metadata])
    |> validate_required([:hash, :archive_url, :metadata])
  end

  def identifier(%__MODULE__{hash: hash, metadata: metadata}) do
    Path.join([
      ~s(deployments),
      metadata.package.organization.slug,
      metadata.package.slug,
      hash
    ])
  end
end
