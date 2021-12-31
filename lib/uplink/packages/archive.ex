defmodule Uplink.Packages.Archive do
  use Ecto.Schema
  import Ecto.Changeset
  
  alias Uplink.Packages.Deployment
  
  schema "archives" do
    field :node, :string
    field :location, :string
    field :current_state, :string, default: "created"
    
    belongs_to :deployment, Deployment
    
    timestamps(type: :utc_datetime_usec)
  end
  
  def changeset(archive, params) do
    archive
    |> cast(params, [:node, :location])
    |> validate_required([:node, :location])
  end
end