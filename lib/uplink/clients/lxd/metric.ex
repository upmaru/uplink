defmodule Uplink.Clients.LXD.Metric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :instance, :string
    field :label, :string
    field :value, :string
  end

  def changeset(metric, params) do
    metric
    |> cast(params, [:instance, :type, :value])
    |> validate_required([:instance, :type, :value])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
