defmodule Uplink.Clients.LXD.Network.Lease do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs ~w(
    hostname
    hwaddr
    address
    type
    location
  )a

  @primary_key false
  embedded_schema do
    field :hostname, :string
    field :hwaddr, :string
    field :address, :string
    field :type, :string
    field :location, :string
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
