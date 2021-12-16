defmodule Uplink.Packages.Installation.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.Installation

  @spec get_or_create(integer | binary) :: %Installation{}
  def get_or_create(instellar_installation_id) do
    Installation
    |> Repo.get_by(instellar_installation_id: instellar_installation_id)
    |> case do
      nil ->
        %Installation{}
        |> Installation.changeset(%{
          instellar_installation_id: instellar_installation_id
        })
        |> Repo.insert!()

      %Installation{} = installation ->
        installation
    end
  end
end