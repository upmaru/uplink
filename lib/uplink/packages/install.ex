defmodule Uplink.Packages.Install do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query, only: [from: 2]

  alias Uplink.Packages.Deployment

  use Eventful.Transitable,
    transitions_module: __MODULE__.Transitions

  schema "installs" do
    field :instellar_installation_id, :integer
    field :current_state, :string, default: "created"

    belongs_to :deployment, Deployment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(install, params) do
    install
    |> cast(params, [:instellar_installation_id])
    |> validate_required([:instellar_installation_id])
  end

  def latest_by_installation_id(count \\ 1) do
    ranking_query =
      from(
        i in __MODULE__,
        select: %{
          id: i.id,
          row_number: over(row_number(), :installations_partition)
        },
        windows: [
          installations_partition: [
            partition_by: :instellar_installation_id,
            order_by: [desc: :inserted_at]
          ]
        ]
      )

    from(
      i in __MODULE__,
      join: r in subquery(ranking_query),
      on: i.id == r.id and r.row_number <= ^count
    )
  end
end
