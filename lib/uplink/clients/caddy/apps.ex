defmodule Uplink.Clients.Caddy.Apps do
  use Ecto.Schema
  import Ecto.Changeset
  
  alias __MODULE__.Server

  @primary_key false
  embedded_schema do
    embeds_one :http, Http, primary_key: false do
      field :servers, :map
    end
  end
  
  def changeset(apps, params) do
    apps
    |> cast(params, [:servers])
    |> maybe_cast_servers()
  end
  
  def maybe_cast_servers(changeset) do
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
