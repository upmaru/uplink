defmodule Uplink.Clients.Caddy.Issuers.DNS.Cloudflare do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :name, :string, default: "cloudflare"
    field :api_token, :string
  end

  def changeset(cloudflare, params) do
    cloudflare
    |> cast(params, [:api_token])
    |> validate_required([:api_token])
  end

  def create!(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
