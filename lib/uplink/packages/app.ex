defmodule Uplink.Packages.App do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.{
    Deployment
  }

  schema "apps" do
    field :slug, :string

    has_many :deployments, Deployment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(app, params) do
    app
    |> cast(params, [:slug])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end
end
