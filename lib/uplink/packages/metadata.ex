defmodule Uplink.Packages.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one :installation, Installation, primary_key: false do
      field :id, :integer
      field :slug, :string
      field :service_port, :integer
      field :exposed_port, :integer

      embeds_one :channel, Channel, primary_key: false do
        field :slug, :string

        embeds_one :package, Package, primary_key: false do
          field :slug, :string

          embeds_one :credential, Credential, primary_key: false do
            field :public_key, :string
          end

          embeds_one :organization, Organization, primary_key: false do
            field :slug
          end
        end
      end

      embeds_many :instances, Instance, primary_key: false do
        field :installation_instance_id, :integer
        field :slug, :string

        embeds_one :node, Node, primary_key: false do
          field :slug, :string
        end
      end
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
    |> cast_embed(:cluster, required: true, with: &cluster_changeset/2)
    |> cast_embed(:installation, required: true, with: &installation_changeset/2)
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

  defp package_changeset(package, params) do
    package
    |> cast(params, [:slug])
    |> validate_required([:slug])
    |> cast_embed(:organization, required: true, with: &organization_changeset/2)
    |> cast_embed(:credential,
      required: true,
      with: &package_credential_changeset/2
    )
  end

  defp package_credential_changeset(package_credential, params) do
    package_credential
    |> cast(params, [:public_key])
    |> validate_required([:public_key])
  end

  defp installation_changeset(installation, params) do
    installation
    |> cast(params, [:id, :slug])
    |> validate_required([:id, :slug])
    |> cast_embed(:channel, required: true, with: &channel_changeset/2)
    |> cast_embed(:instances, required: true, with: &instance_changeset/2)
  end

  defp channel_changeset(channel, params) do
    channel
    |> cast(params, [:slug])
    |> validate_required([:slug])
    |> cast_embed(:package, required: true, with: &package_changeset/2)
  end

  defp instance_changeset(instance, params) do
    instance
    |> cast(params, [:installation_instance_id, :slug])
    |> validate_required([:installation_instance_id, :slug])
    |> cast_embed(:node, required: true, with: &node_changeset/2)
  end

  defp node_changeset(node, params) do
    node
    |> cast(params, [:slug])
    |> validate_required([:slug])
  end

  def app_slug(%__MODULE__{installation: installation}) do
    [
      installation.channel.package.organization.slug,
      installation.channel.package.slug
    ]
    |> Enum.join("/")
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
