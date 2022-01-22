defmodule Uplink.Clients.LXD.Instance do
  use Ecto.Schema
  import Ecto.Changeset
  
  @valid_attrs ~w(
    name
    type
    location
    status
    architecture
    profiles
    description
    created_at
    last_used_at
    expanded_config
  )a
  
  @required_attrs ~w(
    name
    type
    location
    status
    architecture
    profiles
    created_at
    last_used_at
  )a
  
  @primary_key false
  embedded_schema do
    field :name, :string
    field :type, :string
    field :location, :string
    field :status, :string
    field :architecture, :string
    field :profiles, {:array, :string}
    field :description, :string
    
    field :created_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
      
    field :expanded_config, :map
    field :expanded_devices, :map
  end
  
  def changeset(schema, params) do
    schema
    |> cast(params, @valid_attrs)
    |> validate_required(@required_attrs)
  end
  
  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end