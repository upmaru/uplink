defmodule Uplink.Availability.Requirement do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :node, :string
    field :instances, {:array, :string}

    field :cpu, :decimal
    field :memory, :decimal
    field :disk, :decimal

    field :actual_cpu, :decimal
    field :actual_memory, :decimal
    field :actual_disk, :decimal
  end

  def changeset(requirement, params) do
    requirement
    |> cast(params, [:node, :instances, :cpu, :memory, :disk])
    |> validate_required([:node, :instances, :cpu, :memory, :disk])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
