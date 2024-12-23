defmodule Uplink.Packages.Metadata.Port do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :slug, :string
    field :source, :integer
    field :target, :integer

    embeds_one :routing, Routing, primary_key: false do
      field :router_id, :integer
      field :hosts, {:array, :string}, default: []
      field :paths, {:array, :string}, default: ["*"]
    end
  end

  def changeset(port, params) do
    port
    |> cast(params, [:slug, :source, :target])
    |> validate_required([:slug, :source, :target])
    |> cast_embed(:routing, with: &routing_changeset/2)
  end

  defp routing_changeset(routing, params) do
    routing
    |> cast(params, [:router_id, :hosts, :paths])
    |> validate_required([:router_id, :paths])
  end
end
