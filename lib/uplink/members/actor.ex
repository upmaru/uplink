defmodule Uplink.Members.Actor do
  use Ecto.Schema
  import Ecto.Changeset

  schema "actors" do
    field :identifier, :string

    field :reference, :string
    field :provider, :string, default: "internal"

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(actor, params) do
    actor
    |> cast(params, [:identifier, :provider, :reference])
    |> validate_required([:identifier, :provider])
    |> validate_inclusion(:provider, ["instellar", "internal"])
    |> unique_constraint(:reference, name: :actors_provider_reference_index)
  end
end
