defmodule Uplink.Availability.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :node, :string

    embeds_one :available, Available, primary_key: false do
      field :cpu_cores, :integer
      field :memory_bytes, :decimal
      field :storage_bytes, :decimal
    end

    embeds_one :usage, Usage, primary_key: false do
      field :load_norm_5, :decimal
      field :memory_bytes, :decimal
      field :storage_bytes, :decimal
    end
  end

  def changeset(resource, params) do
    resource
    |> cast(params, [:node])
    |> cast_embed(:available, with: &available_changeset/2)
    |> cast_embed(:usage, with: &usage_changeset/2)
  end

  def available_changeset(available, params) do
    available
    |> cast(params, [:cpu_cores, :memory_bytes, :storage_bytes])
  end

  def usage_changeset(usage, params) do
    usage
    |> cast(params, [:load_norm_5, :memory_bytes, :storage_bytes])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
