defmodule Uplink.Availability.Requirement do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs [
    :node,
    :instances,
    :processing,
    :memory,
    :storage,
    :actual_processing,
    :actual_memory,
    :actual_storage
  ]

  @required_attrs [
    :node,
    :instances,
    :processing,
    :memory,
    :storage
  ]

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :node, :string
    field :instances, {:array, :string}

    field :processing, :decimal
    field :memory, :decimal
    field :storage, :decimal

    field :actual_processing, :decimal
    field :actual_memory, :decimal
    field :actual_storage, :decimal
  end

  def changeset(requirement, params) do
    requirement
    |> cast(params, @valid_attrs)
    |> validate_required(@required_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
