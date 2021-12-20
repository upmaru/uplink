defmodule Uplink.Packages.Deployment.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.{
    Storage
  }

  @primary_key false
  embedded_schema do
    embeds_one :storage, Storage
  end

  def changeset(%__MODULE__{} = metadata, params) do
    metadata
    |> cast(params, [])
    |> cast_embed(:storage, require: true)
  end
end
