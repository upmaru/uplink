defmodule Uplink.Availability.Requirement.Params do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :project, :string
    field :processing, :decimal
    field :memory, :decimal
    field :storage, :decimal
  end

  def changeset(params_struct, params) do
    params_struct
    |> cast(params, [:project, :processing, :memory, :storage])
    |> validate_required([:project, :processing, :memory, :storage])
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
