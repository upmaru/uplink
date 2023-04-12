defmodule Uplink.Packages.Archive do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uplink.Packages.Deployment

  import Ecto.Query, only: [from: 2]

  schema "archives" do
    field :node, :string
    field :locations, {:array, :string}

    belongs_to :deployment, Deployment

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(archive, params) do
    archive
    |> cast(params, [:node, :locations])
    |> validate_required([:node, :locations])
    |> unique_constraint(:deployment_id)
  end

  def latest_by_app_id(count \\ 1) do
    ranking_query =
      from(
        a in __MODULE__,
        join: d in assoc(a, :deployment),
        select: %{
          id: a.id,
          row_number: over(row_number(), :archives_partition)
        },
        windows: [
          archives_partition: [
            partition_by: d.app_id,
            order_by: [desc: :inserted_at]
          ]
        ]
      )

    from(a in __MODULE__,
      join: r in subquery(ranking_query),
      on: a.id == r.id and r.row_number <= ^count
    )
  end
end
