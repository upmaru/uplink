defmodule Uplink.Packages.Installation.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.{
    Deployment,
    Installation
  }

  @spec create(%Deployment{}, integer | binary) ::
          {:ok, %Installation{}} | {:error, Ecto.Changeset.t()}
  def create(%Deployment{id: deployment_id}, instellar_installation_id) do
    %Installation{deployment_id: deployment_id}
    |> Installation.changeset(%{
      instellar_installation_id: instellar_installation_id
    })
    |> Repo.insert()
  end
end
