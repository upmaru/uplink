defmodule Uplink.Packages.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one :package, Package, primary_key: false do
      field :slug, :string

      embeds_one :organization, Organization, primary_key: false do
        field :slug
      end
    end

    embeds_many :instances, Instance, primary_key: false do
      field :slug, :string
    end

    embeds_one :cluster, Cluster, primary_key: false do
      field :type, :string
      field :credential, :map

      embeds_one :organization, Organization, primary_key: false do
        field :slug
      end
    end
  end

  def changeset(%__MODULE__{} = metadata, params) do
    metadata
    |> cast(params, [])
    |> cast_embed(:package, required: true, with: &package_changeset/2)
    |> cast_embed(:cluster, required: true, with: &cluster_changeset/2)
  end

  defp package_changeset(package, params) do
    package
    |> cast(params, [:slug])
    |> validate_required([:slug])
    |> cast_embed(:organization, required: true, with: &organization_changeset/2)
  end

  defp cluster_changeset(cluster, params) do
    cluster
    |> cast(params, [:type, :credential])
    |> cast_embed(:organization, required: true, with: &organization_changeset/2)
  end

  defp organization_changeset(organization, params) do
    organization
    |> cast(params, [:slug])
    |> validate_required([:slug])
  end

  def app_slug(%__MODULE__{package: package}) do
    [package.organization.slug, package.slug]
    |> Enum.join("/")
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
