defmodule Uplink.Packages.Deployment.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.{
    Storage,
    Organization,
    Package
  }

  @primary_key false
  embedded_schema do
    embeds_one :storage, Storage
    embeds_one :package, Package
    embeds_one :organization, Organization
  end

  def changeset(%__MODULE__{} = metadata, params) do
    metadata
    |> cast(params, [])
    |> cast_embed(:storage, require: true)
  end
end
