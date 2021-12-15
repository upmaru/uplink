defmodule Uplink.Members.Actor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "actors" do
    field(:identifier, :string)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(actor, params) do
    actor
    |> cast(params, [:identifier])
    |> validate_required([:identifier])
  end
end
