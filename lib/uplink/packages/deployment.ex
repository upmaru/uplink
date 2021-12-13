defmodule Uplink.Packages.Deployment do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "deployments" do
    field :current_state, :string, default: "created"
    field :instellar_installation_id, :integer, null: false
    
    timestamps(type: :utc_datetime_usec)
  end
  
  def changeset(deployment, params) do
    deployment
    |> cast(params, [:instellar_installation_id])
  end
end