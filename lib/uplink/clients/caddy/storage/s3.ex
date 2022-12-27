defmodule Uplink.Clients.Caddy.Storage.S3 do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  @attrs ~w(host bucket access_id secret_key prefix)

  @required ~w(host bucket access_id secret_key)

  @primary_key false
  embedded_schema do
    field :module, :string, default: "s3"
    field :host, :string
    field :bucket, :string
    field :access_id, :string
    field :secret_key, :string
    field :prefix, :string
  end

  def changeset(s3, params) do
    s3
    |> cast(params, @attrs)
    |> validate_required(@required)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
