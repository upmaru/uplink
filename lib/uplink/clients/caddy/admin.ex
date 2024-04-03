defmodule Uplink.Clients.Caddy.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    embeds_one :identity, Identity, primary_key: false do
      @derive Jason.Encoder

      field :identifiers, {:array, :string}
      field :issuers, {:array, :map}, default: []
    end
  end

  def changeset(admin, params) do
    admin
    |> cast(params, [])
    |> cast_embed(:identity, with: &identity_changeset/2)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end

  defp identity_changeset(identity, params) do
    identity
    |> cast(params, [:identifiers, :issuers])
  end
end
