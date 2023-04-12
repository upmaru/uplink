defmodule Uplink.Members.Actor.Params do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :provider, :string
    field :identifier, :string
  end

  def changeset(params, attrs) do
    params
    |> cast(attrs, [:id, :provider, :identifier])
    |> validate_required([:id, :provider, :identifier])
  end

  def build(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
