defmodule Uplink.Clients.Caddy.Apps.Server do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :listen, {:array, :string}

    embeds_many :routes, Route, primary_key: false do
      field :group, :string, default: ""

      embeds_many :match, Match, primary_key: false do
        field :host, {:array, :string}
      end

      field :handle, {:array, :map}
      field :terminal, :boolean, default: false
    end
  end

  def changeset(server, params) do
    server
    |> cast(params, [:listen])
    |> cast_embed(:routes, with: &route_changeset/2)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end

  defp route_changeset(route, params) do
    route
    |> cast(params, [:handle])
    |> cast_embed(:match, with: &match_changeset/2)
  end

  defp match_changeset(match, params) do
    match
    |> cast(params, [:host])
  end
end
