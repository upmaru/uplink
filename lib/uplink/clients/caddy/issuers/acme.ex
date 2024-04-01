defmodule Uplink.Clients.Caddy.Issuers.ACME do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Clients.Caddy.Issuers.DNS
  alias Uplink.Clients.Caddy.Issuers.Challenge

  @derive Jason.Encoder

  @primary_key false
  embedded_schema do
    field :module, :string, default: "acme"
    field :ca, :string, default: ""
    field :test_ca, :string, default: ""
    field :email, :string, default: ""
    field :account_key, :string, default: ""

    embeds_one :external_account, ExternalAccount, primary_key: false do
      @derive Jason.Encoder

      field :key_id, :string, default: ""
      field :mac_key, :string, default: ""
    end

    field :acme_timeout, :integer, default: 0

    embeds_one :challenges, Challenges, primary_key: false do
      @derive Jason.Encoder

      embeds_one :http, Challenge
      embeds_one :tls_alpn, Challenge
      embeds_one :dns, DNS

      field :bind_host, :string, default: ""
    end

    field :trusted_roots_pem_files, {:array, :string}, default: [""]

    embeds_one :preferred_chains, PreferredChains, primary_key: false do
      @derive Jason.Encoder

      field :smallest, :boolean, default: false
      field :root_common_name, {:array, :string}, default: [""]
      field :any_common_name, {:array, :string}, default: [""]
    end
  end

  def changeset(acme, params) do
    acme
    |> cast(params, [:ca, :test_ca, :email, :account_key])
    |> cast_embed(:external_account, with: &external_account_changeset/2)
    |> cast_embed(:challenges, with: &challenges_changeset/2)
    |> cast_embed(:preferred_chains, with: &preferred_chains_changeset/2)
  end

  def create!(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end

  defp external_account_changeset(external_account, params) do
    external_account
    |> cast(params, [:key_id, :mac_key])
  end

  defp challenges_changeset(challenges, params) do
    challenges
    |> cast(params, [:bind_host])
    |> cast_embed(:http)
    |> cast_embed(:tls_alpn)
    |> cast_embed(:dns)
  end

  defp preferred_chains_changeset(preferred_chains, params) do
    preferred_chains
    |> cast(params, [:smallest, :root_common_name, :any_common_name])
  end
end
