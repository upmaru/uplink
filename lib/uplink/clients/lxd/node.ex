defmodule Uplink.Clients.LXD.Node do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :cpu_cores_count, :integer
  end

  def changeset(node, params) do
    node
    |> cast(params, [:name, :cpu_cores_count])
    |> validate_required([:name, :cpu_cores_count])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
