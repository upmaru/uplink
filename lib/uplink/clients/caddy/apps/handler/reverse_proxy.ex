defmodule Uplink.Clients.Caddy.Apps.Handler.ReverseProxy do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :handler, :string

    embeds_one :load_balancing, LoadBalancing, primary_key: false do
      @derive Jason.Encoder

      field :selection_policy, :string
      field :retries, :integer, default: 0
      field :try_duration, :integer, default: 0
      field :try_interval, :integer, default: 0
    end

    embeds_one :health_checks, HealthChecks, primary_key: false do
      @derive Jason.Encoder

      embeds_one :active, Active, primary_key: false do
        @derive Jason.Encoder

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
      @derive Jason.Encoder

      field :dial, :string, default: ""
      field :max_requests, :integer, default: 10
    end
  end

  def changeset(reverse_proxy, params) do
    reverse_proxy
    |> cast(params, [:handler])
    |> cast_embed(:health_checks, with: &health_checks_changeset/2)
    |> cast_embed(:upstreams, with: &upstream_changeset/2)
    |> cast_embed(:load_balancing, with: &load_balancing_changeset/2)
  end

  defp load_balancing_changeset(load_balancing, params) do
    load_balancing
    |> cast(params, [:selection_policy, :retries, :try_duration, :try_interval])
  end

  defp health_checks_changeset(health_checks, params) do
    health_checks
    |> cast(params, [])
    |> cast_embed(:active, with: &active_health_check_changeset/2)
  end

  defp upstream_changeset(upstream, params) do
    upstream
    |> cast(params, [:dial, :max_requests])
  end

  defp active_health_check_changeset(active_health_check, params) do
    active_health_check
    |> cast(params, [
      :path,
      :uri,
      :port,
      :headers,
      :interval,
      :timeout,
      :max_size,
      :expect_status,
      :expect_body
    ])
  end
end
