defmodule Uplink.Packages.Metadata.Orchestration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :placement, :string, default: "auto"
    field :on_fail, :string, default: "cleanup"
    field :delivery, :string, default: "continuous"
    field :upgrade, :string, default: "patch"
  end

  def changeset(orchestration, attrs) do
    orchestration
    |> cast(attrs, [:placement, :on_fail, :delivery, :upgrade])
    |> validate_inclusion(:placement, ["auto", "spread"])
    |> validate_inclusion(:upgrade, ["patch"])
    |> validate_inclusion(:delivery, ["continuous", "manual"])
    |> validate_inclusion(:on_fail, ["cleanup", "restart"])
  end
end
