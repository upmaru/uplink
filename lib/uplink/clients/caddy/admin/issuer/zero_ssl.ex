defmodule Uplink.Clients.Caddy.Admin.Issuer.ZeroSSL do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs ~w(
    api_key
  )a

  @primary_key false
  embedded_schema do
    field :module, :string, default: "zerossl"
    field :api_key, :string
  end

  def changeset(issuer, params) do
    issuer
    |> cast(params, @valid_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
