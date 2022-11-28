defmodule Uplink.Clients.Caddy.Apps.Server do
	use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key false
  embedded_schema do
    field :listen, {:array, :string}
    
    embeds_many :routes, Route, primary_key: false do
      embeds_many :match, Match, primary_key: false do
        field :host, {:array, :string}
      end
      
      field :handle, {:array, :map}
    end
  end
  
  def changeset(server, params) do
    server
    |> cast(params, [:listen])
    |> cast_assoc(:routes, with: &route_changeset/2)
  end
  
  defp route_changeset(route, params) do
    route
    |> cast(params, [:handle])
    |> cast_assoc(:match, with: &match_changeset/2)
  end
  
  defp match_changeset(match, params) do
    match
    |> cast(params, [:host])
  end
end