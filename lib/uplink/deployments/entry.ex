defmodule Uplink.Deployments.Entry do
  use Memento.Table, 
    attributes: [
      :id, 
      :instellar_deployment_id, 
      :current_state,
      :inserted_at, 
      :updated_at
    ],
    type: :ordered_set,
    autoincrement: true
  
  import Ecto.Changeset
  
  def __changeset__ do
    %{
      id: :id, 
      instellar_deployment_id: :integer, 
      current_state: :string,
      inserted_at: :integer,
      updated_at: :integer
    }  
  end
  
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:current_state, :slug])
    |> validate_inclusion(:current_state, ["created"])
  end
  
  def parse(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> generate_timestamps()
    |> apply_action(:insert)  
  end
  
  defp generate_timestamps(changeset) do
    now = 
      DateTime.utc_now()
      |> DateTime.to_unix()
    
    changeset
    |> put_change(:inserted_at, now)
    |> put_change(:updated_at, now)  
  end
end