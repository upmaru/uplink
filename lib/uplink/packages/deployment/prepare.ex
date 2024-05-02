defmodule Uplink.Packages.Deployment.Prepare do
  use Oban.Worker, queue: :deployment, max_attempts: 1

  require Logger

  alias Uplink.{
    Members,
    Packages,
    Repo
  }

  alias Packages.{
    Deployment
  }

  @logger_prefix "[Uplink.Packages.Deployment.Prepare]"

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"deployment_id" => deployment_id, "actor_id" => actor_id}
      }) do
    actor = Repo.get(Members.Actor, actor_id)

    %Deployment{} =
      deployment =
      Deployment
      |> Repo.get(deployment_id)
      |> Repo.preload([:app])

    if deployment.current_state == "live" do
      {:ok, :already_live}
    else
      handle_prepare(deployment, actor)
    end
  end

  defp handle_prepare(
         %Deployment{
           hash: hash,
           archive_url: archive_url
         } = deployment,
         %Members.Actor{} = actor
       ) do
    identifier = Deployment.identifier(deployment)

    state = {deployment, actor, identifier}

    tmp_path = Path.join("tmp", "archives")
    archive_file_path = Path.join(tmp_path, "#{hash}.zip")
    extraction_path = Path.join(tmp_path, "#{hash}")

    File.mkdir_p!(tmp_path)

    Logger.info("#{@logger_prefix} Downloading archive - #{identifier}")

    archive_url
    |> Req.get(into: File.stream!(archive_file_path))
    |> case do
      {:ok, %{status: 200}} ->
        decompress_archive(archive_file_path, extraction_path, state)

      _ ->
        comment = "Download Failed"
        log = "#{@logger_prefix} #{comment} - #{identifier}"
        Logger.error(log)

        Packages.transition_deployment_with(deployment, actor, "fail",
          comment: comment
        )
    end
  end

  defp decompress_archive(
         path,
         extraction_path,
         {deployment, actor, identifier} = state
       ) do
    Logger.info("#{@logger_prefix} Unzipping archive - #{identifier}")

    path
    |> to_charlist()
    |> :zip.unzip([{:cwd, to_charlist(extraction_path)}])
    |> case do
      {:ok, paths} ->
        tmp_path = Path.join(["tmp", "deployments", deployment.channel])
        File.mkdir_p!(tmp_path)

        [_, org, package, _] = String.split(identifier, "/")

        destination = Path.join([tmp_path, org, package])

        paths
        |> Enum.map(&process_extracted_file(&1, destination))
        |> validate_and_finalize_deployment(paths, state)

      _ ->
        comment = "Unzipping archive failed"
        log = "#{@logger_prefix} #{comment} - #{identifier}"
        Logger.error(log)

        Packages.transition_deployment_with(deployment, actor, "fail",
          comment: comment
        )
    end
  end

  defp process_extracted_file(path, destination) do
    path = to_string(path)

    file_with_arch_name =
      path
      |> Path.split()
      |> Enum.take(-2)
      |> Path.join()

    storage_path = Path.join(destination, file_with_arch_name)

    File.mkdir_p!(Path.dirname(storage_path))

    case File.rename(path, storage_path) do
      :ok ->
        {:ok, storage_path}

      error ->
        error
    end
  end

  defp validate_and_finalize_deployment(
         results,
         paths,
         {deployment, actor, identifier}
       ) do
    successful_uploads =
      Enum.filter(results, fn {result, _} -> result == :ok end)

    if Enum.count(successful_uploads) == Enum.count(paths) do
      Logger.info("#{@logger_prefix} Deployment completed - #{identifier}")

      params = %{
        node: Atom.to_string(Node.self()),
        locations:
          Enum.map(successful_uploads, fn {_result, file_path} ->
            file_path
          end)
      }

      case Packages.create_archive(deployment, params) do
        {:ok, _archive} ->
          Packages.transition_deployment_with(deployment, actor, "complete")

        {:error,
         %{
           errors: [
             deployment_id: {_, [constraint: :unique, constraint_name: _]}
           ]
         }} ->
          update_archive_and_transition(deployment, actor)

        {:error, _error} ->
          Packages.transition_deployment_with(deployment, actor, "fail",
            comment: "archive not created"
          )
      end
    else
      comment = "Upload partially failed"
      Logger.error("#{@logger_prefix} #{comment} - #{identifier}")

      Packages.transition_deployment_with(deployment, actor, "fail",
        comment: comment
      )
    end
  end

  defp update_archive_and_transition(deployment, actor) do
    Packages.Archive
    |> Repo.get_by(deployment_id: deployment.id)
    |> Packages.update_archive(%{node: to_string(Node.self())})
    |> case do
      {:ok, _archive} ->
        Packages.transition_deployment_with(deployment, actor, "complete")

      {:error, _error} ->
        Packages.transition_deployment_with(deployment, actor, "fail",
          comment: "archive node could not be updated"
        )
    end
  end
end
