defmodule Uplink.Availability.Placeability do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :cpu, :decimal
    field :memory, :decimal
    field :disk, :decimal
  end

  def changeset(placeability, params) do
    placeability
    |> cast(params, [:cpu, :memory, :disk])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
