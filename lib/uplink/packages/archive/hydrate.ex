defmodule Uplink.Packages.Archive.Hydrate do
  use Oban.Worker, queue: :prepare_deployment, max_attempts: 1

  alias Uplink.{
    Clients,
    Members,
    Packages,
    Repo
  }

  alias Clients.Instellar

  alias Packages.{
    Archive,
    Deployment,
    Install
  }

  require Logger

  import Ecto.Query, only: [where: 3, preload: 2, limit: 2]

  def perform(%Job{args: %{"archive_id" => archive_id, "actor_id" => actor_id}}) do
    actor = Repo.get(Members.Actor, actor_id)

    %Archive{node: node} =
      archive =
      Archive
      |> Repo.get(archive_id)
      |> Repo.preload(deployment: [:app])

    if node == to_string(Node.self()) do
      maybe_handle_hydration(archive, actor)
    else
      {:ok, :archive_on_different_node}
    end
  end

  defp maybe_handle_hydration(%Archive{deployment: deployment} = archive, actor) do
    with {:ok, %{resource: hydrating_deployment}} <-
           Packages.transition_deployment_with(deployment, actor, "hydrate") do
      if already_exists?(archive) do
        Packages.transition_deployment_with(
          hydrating_deployment,
          actor,
          "complete"
        )

        {:ok, :archive_already_exists}
      else
        handle_hydration(
          %Archive{archive | deployment: hydrating_deployment},
          actor
        )
      end
    end
  end

  defp handle_hydration(%Archive{deployment: deployment}, actor) do
    with {:ok, %{"archive_url" => archive_url}} <-
           Install
           |> where([i], i.deployment_id == ^deployment.id)
           |> preload([:deployment])
           |> limit(1)
           |> Repo.one()
           |> Instellar.get_deployment(),
         {:ok, _updated_deployment} <-
           Packages.update_deployment(deployment, %{archive_url: archive_url}) do
      Deployment.Prepare.perform(%Oban.Job{
        args: %{"deployment_id" => deployment.id, "actor_id" => actor.id}
      })
    else
      {:error, error} ->
        Packages.transition_deployment_with(deployment, actor, "fail",
          comment: "#{__MODULE__} handle_hydration/2"
        )
    end
  end

  defp already_exists?(%Archive{locations: locations}) do
    locations
    |> Enum.map(fn path -> File.exists?(path) end)
    |> Enum.all?()
  end
end
