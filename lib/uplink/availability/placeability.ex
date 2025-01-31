defmodule Uplink.Availability.Placeability do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs [
    :processing,
    :memory,
    :storage
  ]

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :processing, :decimal
    field :memory, :decimal
    field :storage, :decimal
  end

  def changeset(placeability, params) do
    placeability
    |> cast(params, @valid_attrs)
    |> validate_required(@valid_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
