defmodule Uplink.Clients.Caddy.Issuers.DNS do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :provider, :map, default: %{}
    field :ttl, :integer, default: 0
    field :propagation_delay, :integer, default: 0
    field :propagation_timeout, :integer, default: 0
    field :resolvers, {:array, :string}, default: [""]
    field :override_domain, :string, default: ""
  end

  def changeset(dns, params) do
    dns
    |> cast(params, [
      :provider,
      :ttl,
      :propagation_delay,
      :propagation_timeout,
      :resolvers,
      :override_domain
    ])
  end
end
