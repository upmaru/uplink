defmodule Uplink.Packages.Archive do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Deployment

  schema "archives" do
    field :node, :string
    field :locations, {:array, :string}

    belongs_to :deployment, Deployment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(archive, params) do
    archive
    |> cast(params, [:node, :locations])
    |> validate_required([:node, :locations])
    |> unique_constraint(:deployment_id)
  end
end
