defmodule Uplink.Deployments.Entry do
  use Memento.Table, 
    attributes: [:id, :slug, :current_state],
    type: :ordered_set,
    autoincrement: true
  
  import Ecto.Changeset
  
  def __changeset__ do
    %{id: :id, slug: :string, current_state: :string}
  end
  
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:current_state, :slug])
    |> validate_inclusion(:current_state, ["created", "processing", "completed"])
  end
  
  def parse(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)  
  end
end