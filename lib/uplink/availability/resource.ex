defmodule Uplink.Availability.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :node, :string

    embeds_one :total, Total, primary_key: false do
      field :cpu_cores, :integer
      field :memory_bytes, :decimal
      field :storage_bytes, :decimal
    end

    embeds_one :used, Used, primary_key: false do
      field :load_norm_5, :decimal
      field :memory_bytes, :decimal
      field :storage_bytes, :decimal
    end

    embeds_one :available, Available, primary_key: false do
      field :processing, :decimal
      field :memory, :decimal
      field :storage, :decimal
    end
  end

  def changeset(resource, params) do
    resource
    |> cast(params, [:node])
    |> cast_embed(:total, with: &total_changeset/2)
    |> cast_embed(:used, with: &used_changeset/2)
    |> cast_embed(:available, with: &available_changeset/2)
  end

  def total_changeset(available, params) do
    available
    |> cast(params, [:cpu_cores, :memory_bytes, :storage_bytes])
  end

  def used_changeset(used, params) do
    used
    |> cast(params, [:load_norm_5, :memory_bytes, :storage_bytes])
  end

  def available_changeset(available, params) do
    available
    |> cast(params, [:processing, :memory, :storage])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
