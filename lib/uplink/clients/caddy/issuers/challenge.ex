defmodule Uplink.Clients.Caddy.Issuers.Challenge do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :disabled, :boolean, default: false
    field :alternate_port, :integer, default: 0
  end

  def changeset(challenge, params) do
    challenge
    |> cast(params, [:disabled, :alternate_port])
  end
end
