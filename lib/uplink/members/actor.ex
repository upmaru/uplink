defmodule Uplink.Members.Actor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "actors" do
    field(:identifier, :string)
    field(:provider, :string, default: "instellar")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(actor, params) do
    actor
    |> cast(params, [:identifier, :provider])
    |> validate_required([:identifier])
    |> validate_inclusion(:provider, ["instellar", "internal"])
  end
end
