defmodule Uplink.Packages.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.{
    Storage
  }

  @primary_key false
  embedded_schema do
    embeds_one :package, Package do
      field :slug
    end

    embeds_one :cluster, Cluster do
      field :type, :string
      field :credential, :map

      embeds_one :organization, Organization do
        field :slug

        embeds_one :storage, Storage
      end
    end
  end

  def changeset(%__MODULE__{} = metadata, params) do
    metadata
    |> cast(params, [])
    |> cast_embed(:package, require: true)
    |> cast_embed(:cluster, require: true)
  end
  
  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
