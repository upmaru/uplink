defmodule Uplink.Clients.LXD.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs ~w(
    config
    description
    devices
    name
    used_by
  )a

  @primary_key false
  embedded_schema do
    field :config, :map
    field :description, :string
    field :name, :string
    field :devices, :map
    field :used_by, {:array, :string}
  end

  def changeset(schema, params) do
    schema
    |> cast(params, @valid_attrs)
    |> validate_required(@valid_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
