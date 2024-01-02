defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.{
    App,
    Archive,
    Install
  }

  @valid_attrs ~w(
    hash
    channel
    archive_url
    stack
  )a

  @required_attrs ~w(
    hash
    channel
    archive_url
    stack
  )a

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "deployments" do
    field :hash, :string
    field :archive_url, :string
    field :channel, :string
    field :stack, :string
    field :current_state, :string, default: "created"

    belongs_to :app, App

    has_one :archive, Archive

    has_many :installs, Install

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(deployment, params) do
    deployment
    |> cast(params, @valid_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash,
      name: :deployments_app_id_hash_index
    )
  end

  def update_changeset(deployment, params) do
    deployment
    |> cast(params, [:archive_url])
    |> validate_required([:archive_url])
  end

  def identifier(%__MODULE__{hash: hash, app: app}) do
    Path.join([~s(deployments), app.slug, hash])
  end
end
