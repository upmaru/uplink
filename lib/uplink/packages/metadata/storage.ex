defmodule Uplink.Packages.Metadata.Storage do
  use Ecto.Schema
  import Ecto.Changeset
  
  @valid_attrs ~w(
    type
    port
    scheme
    host
    bucket
    region
    credential
  )a
  
  @primary_key false
  embedded_schema do
    field :type, :string, default: "s3"
    field :port, :integer, default: 443
    field :scheme, :string, default: "https://"
    
    field :host, :string
    field :bucket, :string
    field :region, :string
    field :credential, :map
  end
  
  def changeset(%__MODULE__{} = storage, params) do
    storage
    |> cast([], params)
    |> validate_required(@valid_attrs)
  end
end