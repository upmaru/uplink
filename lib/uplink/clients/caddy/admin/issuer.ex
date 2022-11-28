defmodule Uplink.Clients.Caddy.Admin.Issuer do
	use Ecto.Schema
  import Ecto.Changeset
  
  @valid_attrs ~w(
    module
  )a
  
  @primary_key false
  embedded_schema do
    field :module, :string
    field :api_key, :string
  end
  
  def changeset(issuer, params) do
    issuer
    |> cast(params, @valid_attrs)
    |> validate_inclusion(:module, ["zerossl", "acme", "internal"])
  end
end