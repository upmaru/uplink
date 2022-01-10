defmodule Uplink.Clients.LXD.Network do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs ~w(
    config
    description
    type
    managed
    used_by
    status
    locations
  )a

  @primary_key false
  embedded_schema do
    field :config, :map
    field :description, :string
    field :type, :string
    field :managed, :boolean
    field :used_by, {:array, :string}
    field :status, :string
    field :locations, {:array, :string}
  end

  def changeset(schema, params) do
    schema
    |> cast(params, @valid_attrs)
    |> validate_required(@valid_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end

  #   def index(client) do
  #     
  #   end
  # 
  #   def leases(client, %__MODULE__{name: name}) do
  #     
  #   end
end
