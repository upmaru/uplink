defmodule Uplink.Routers.Proxy do
  use Ecto.Schmea
  import Ecto.Changeset

  @valid_attrs ~w(
    hosts
    paths
    target
    port
    tls
    router_id
  )a

  @primary_key false
  embedded_schema do
    field :id, :integer

    field :hosts, {:array, :string}, default: []
    field :paths, {:array, :string}, default: []
    field :target, :string
    field :port, :integer
    field :tls, :boolean

    field :router_id, :integer
  end

  def changeset(proxy, params) do
    proxy
    |> cast(params, @valid_attrs)
    |> validate_required(@valid_attrs)
  end

  def create!(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
