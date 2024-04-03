defmodule Uplink.Clients.Caddy.Apps do
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__.Server

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    embeds_one :http, Http, primary_key: false do
      @derive Jason.Encoder

      field :servers, :map
    end

    embeds_one :tls, TLS, primary_key: false do
      @derive Jason.Encoder

      field :automation, :map
    end
  end

  def changeset(apps, params) do
    apps
    |> cast(params, [])
    |> cast_embed(:http, with: &http_changeset/2)
    |> cast_embed(:tls, with: &tls_changeset/2)
  end

  defp http_changeset(http, params) do
    http
    |> cast(params, [:servers])
    |> maybe_cast_servers()
  end

  defp tls_changeset(tls, params) do
    tls
    |> cast(params, [:automation])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end

  defp maybe_cast_servers(changeset) do
    if servers = get_change(changeset, :servers) do
      servers =
        servers
        |> Enum.map(fn {key, value} ->
          {key, Server.parse(value)}
        end)
        |> Enum.into(%{})

      put_change(changeset, :servers, servers)
    else
      changeset
    end
  end
end
