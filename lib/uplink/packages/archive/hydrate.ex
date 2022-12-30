defmodule Uplink.Packages.Archive.Hydrate do
  use Oban.Worker,
    queue: :prepare_deployment,
    max_attempts: 3,
    unique: [fields: [:args], keys: [:archive_id]]

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

    Archive
    |> Repo.get(archive_id)
    |> Repo.preload(deployment: [:app])
    |> maybe_handle_hydration(actor)
  end

  defp maybe_handle_hydration(
         %Archive{node: node, deployment: deployment} = archive,
         actor
       ) do
    node_module = node_module()

    with :pong <- node_module.ping(:"#{node}"),
         {:ok, %{resource: hydrating_deployment}} <-
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
    else
      :pang -> {:snooze, 10}
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
      {:error, _error} ->
        Packages.transition_deployment_with(deployment, actor, "fail",
          comment: "#{__MODULE__} handle_hydration/2"
        )
    end
  end

  defp already_exists?(%Archive{node: node, locations: locations}) do
    task =
      Task.Supervisor.async({Uplink.TaskSupervisor, :"#{node}"}, fn ->
        locations
        |> Enum.map(fn path -> File.exists?(path) end)
        |> Enum.all?()
      end)

    Task.await(task)
  end

  defp node_module, do: Application.get_env(:uplink, :node, Node)
end
