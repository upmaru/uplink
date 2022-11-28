defmodule Uplink.Clients.Caddy.Apps.Handler.ReverseProxy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :handler, :string

    embeds_one :health_checks, HealthChecks, primary_key: false do
      embeds_one :active, Active, primary_key: false do
        field :path, :string
        field :uri, :string
        field :port, :integer, default: 0
        field :headers, :map

        field :interval, :integer, default: 0
        field :timeout, :integer, default: 0
        field :max_size, :integer, default: 0
        field :expect_status, :integer, default: 0
        field :expect_body, :string, default: ""
      end
    end

    embeds_many :upstreams, Upstream, primary_key: false do
      field :dial, :string, default: ""
      field :max_requests, :integer, default: 10
    end
  end

  def changeset(reverse_proxy, params) do
    reverse_proxy
    |> cast(params, [:handler])
    |> cast_embed(:health_checks, with: &health_checks_changeset/2)
    |> cast_embed(:upstreams, with: &upstream_changeset/2)
  end

  defp health_checks_changeset(health_checks, params) do
    health_checks
    |> cast_embed(:active, with: &active_changeset/2)
  end

  defp upstream_changeset(upstream, params) do
    upstream
    |> cast(params, [:dial, :max_requests])
  end
end
