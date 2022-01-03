defmodule Uplink.Packages.Archive.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Archive

  @spec create(%Packages.Deployment{}, map) ::
          {:ok, %Archive{}} | {:error, Ecto.Changeset.t()}
  def create(deployment, params) do
    %Archive{deployment_id: deployment.id}
    |> Archive.changeset(params)
    |> Repo.insert()
  end
end
