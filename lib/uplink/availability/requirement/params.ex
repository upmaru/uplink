defmodule Uplink.Availability.Requirement.Params do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :project, :string
    field :cpu, :decimal
    field :memory, :decimal
    field :disk, :decimal
  end

  def changeset(params_struct, params) do
    params_struct
    |> cast(params, [:project, :cpu, :memory, :disk])
    |> validate_required([:project, :cpu, :memory, :disk])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
