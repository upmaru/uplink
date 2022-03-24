defmodule Uplink.Packages.Deployment.Prepare do
  use Oban.Worker, queue: :prepare_deployment, max_attempts: 1

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

    handle_prepare(deployment, actor)
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

    file = File.open!(archive_file_path, [:write])

    archive_url
    |> Downstream.get(file)
    |> case do
      {:ok, %{status_code: 200}} ->
        :ok = File.close(file)
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
end
