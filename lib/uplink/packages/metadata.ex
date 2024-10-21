defmodule Uplink.Packages.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.Orchestration

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :slug, :string
    field :hosts, {:array, :string}, default: []

    embeds_one :orchestration, Orchestration

    embeds_one :main_port, __MODULE__.Port

    embeds_many :ports, __MODULE__.Port

    embeds_one :package_size, Size, primary_key: false do
      field :slug, :string

      embeds_one :allocation, Allocation, primary_key: false do
        field :cpu, :integer
        field :cpu_allowance, :string, default: "100%"
        field :cpu_priority, :integer, default: 10
        field :memory, :integer
        field :memory_unit, :string, default: "GiB"
        field :memory_enforce, Ecto.Enum, values: [:hard, :soft], default: :hard
        field :memory_swap, :boolean, default: false
      end
    end

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

    embeds_many :variables, Variable, primary_key: false do
      field :key, :string
      field :value, :string
    end

    embeds_many :instances, Instance, primary_key: false do
      field :id, :integer
      field :slug, :string

      embeds_one :node, Node, primary_key: false do
        field :slug, :string
      end
    end
  end

  def changeset(%__MODULE__{} = metadata, params) do
    metadata
    |> cast(params, [:id, :slug, :hosts])
    |> validate_required([:id, :slug])
    |> cast_embed(:orchestration)
    |> cast_embed(:channel, required: true, with: &channel_changeset/2)
    |> cast_embed(:instances, with: &instance_changeset/2)
    |> cast_embed(:main_port)
    |> cast_embed(:ports)
    |> cast_embed(:variables, with: &variable_changeset/2)
    |> cast_embed(:package_size, with: &package_size_changeset/2)
  end

  defp organization_changeset(organization, params) do
    organization
    |> cast(params, [:slug])
    |> validate_required([:slug])
  end

  defp variable_changeset(variable, params) do
    variable
    |> cast(params, [:key, :value])
    |> validate_required([:key, :value])
  end

  defp package_size_changeset(package_size, params) do
    package_size
    |> cast(params, [:slug])
    |> cast_embed(:allocation, with: &allocation_changeset/2)
  end

  defp allocation_changeset(allocation, params) do
    allocation
    |> cast(params, [
      :cpu,
      :cpu_allowance,
      :cpu_priority,
      :memory,
      :memory_unit,
      :memory_enforce,
      :memory_swap
    ])
    |> validate_inclusion(:memory_unit, ["GiB", "MiB", "GB", "MB"])
    |> validate_number(:cpu_priority,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10
    )
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

  defp channel_changeset(channel, params) do
    channel
    |> cast(params, [:slug])
    |> validate_required([:slug])
    |> cast_embed(:package, required: true, with: &package_changeset/2)
  end

  defp instance_changeset(instance, params) do
    instance
    |> cast(params, [:id, :slug])
    |> validate_required([:id, :slug])
    |> cast_embed(:node, required: true, with: &node_changeset/2)
  end

  defp node_changeset(node, params) do
    node
    |> cast(params, [:slug])
    |> validate_required([:slug])
  end

  def app_slug(%__MODULE__{channel: channel}) do
    [
      channel.package.organization.slug,
      channel.package.slug
    ]
    |> Enum.join("/")
  end

  def parse(params) do
    params =
      if Map.get(params, "orchestration") do
        params
      else
        Map.put(params, "orchestration", %{
          "placement" => "auto",
          "upgrade" => "patch",
          "delivery" => "continuous",
          "on_fail" => "cleanup"
        })
      end

    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
