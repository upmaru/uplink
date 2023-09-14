defmodule Uplink.Packages.Metadata.Port do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :slug, :string
    field :source, :integer
    field :target, :integer
  end

  def changeset(port, params) do
    port
    |> cast(params, [:slug, :source, :target])
    |> validate_required([:slug, :source, :target])
  end
end
