defmodule Uplink.Clients.LXD.Cluster.Member do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_attrs ~w(
    roles
    failure_domain
    config
    server_name
    url
    database
    status
    message
    architecture
  )a

  @required_attrs ~w(
    server_name
    url
    database
    status
    message
    architecture
  )a

  @primary_key false
  embedded_schema do
    field :roles, {:array, :string}
    field :failure_domain, :string
    field :config, :map
    field :server_name, :string
    field :url, :string
    field :database, :boolean
    field :status, :string
    field :message, :string
    field :architecture, :string
  end

  def changeset(member, params) do
    member
    |> cast(params, @valid_attrs)
    |> validate_required(@required_attrs)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action!(:insert)
  end
end
