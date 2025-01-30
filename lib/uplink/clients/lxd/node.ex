defmodule Uplink.Clients.LXD.Node do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :name, :string
    field :cpu_cores_count, :integer
    field :total_memory, :integer
    field :total_storage, :integer
  end

  def changeset(node, params) do
    node
    |> cast(params, [:name, :cpu_cores_count, :total_memory, :total_storage])
    |> validate_required([
      :name,
      :cpu_cores_count,
      :total_memory,
      :total_storage
    ])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
