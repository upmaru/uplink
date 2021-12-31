defmodule Uplink.Packages.Deployment.Prepare do
  use Oban.Worker, queue: :prepare_deployment, max_attempts: 1

  require Logger

  alias ExAws.S3

  alias Uplink.{
    Members,
    Packages,
    Cache,
    Repo
  }

  alias Packages.{
    Deployment,
    Metadata
  }

  alias Uplink.Clients.Instellar

  @logger_prefix "[Uplink.Packages.Deployment.Prepare]"

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"deployment_id" => deployment_id, "actor_id" => actor_id}
      }) do
    %Deployment{} =
      deployment =
      Deployment
      |> Repo.get(deployment_id)
      |> retrieve_metadata()

    actor_id
    |> Members.get_actor()
    |> execute(deployment)
  end

  defp retrieve_metadata(%Deployment{hash: hash} = deployment) do
    key_signature = compute_signature(hash)

    Cache.get({:deployment, key_signature})
    |> case do
      %Metadata{} = metadata ->
        Map.merge(deployment, %{metadata: metadata})

      nil ->
        fetch_deployment_metadata(deployment)
    end
  end

  defp execute(
         %Members.Actor{} = actor,
         %Deployment{
           hash: hash,
           archive_path: archive_path,
           metadata: metadata
         } = deployment
       ) do
    identifier = Deployment.identifier(deployment)

    state = {deployment, actor, identifier}

    tmp_path = Path.join("tmp", "deployments")
    archive_file_path = Path.join(tmp_path, "#{hash}.zip")
    extraction_path = Path.join(tmp_path, "#{hash}")

    File.mkdir_p!(tmp_path)

    Logger.info("#{@logger_prefix} Downloading archive - #{identifier}")

    %Metadata{cluster: %{organization: %{storage: storage}}} = metadata
    
    # here perhaps it is simpler to use signed url from S3
    storage.bucket
    |> S3.download_file(archive_path, archive_file_path)
    |> ExAws.request(Packages.render_metadata_storage(metadata))
    |> case do
      {:ok, _response} ->
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

  defp fetch_deployment_metadata(deployment) do
    with {:ok, metadata_params} <- Instellar.deployment_metadata(deployment),
         {:ok, %Metadata{} = metadata} <-
           Packages.parse_metadata(metadata_params) do
      key_signature = compute_signature(deployment.hash)

      Cache.put({:deployment, key_signature}, metadata)
      Map.merge(deployment, %{metadata: metadata})
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
        paths
        |> Enum.map(&process_extracted_file(&1, state))
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

  defp process_extracted_file(
         path,
         {%Deployment{metadata: metadata}, _actor, identifier}
       ) do
    path = to_string(path)

    %Metadata{
      cluster: %{
        organization: %{
          storage: storage
        }
      }
    } = metadata

    file_with_arch_name =
      path
      |> Path.split()
      |> Enum.take(-2)
      |> Path.join()

    storage_path = Path.join(identifier, file_with_arch_name)
    
    # TODO: here instead of uploading to S3 we create directory structure locally
    # path
    # |> S3.Upload.stream_file()
    # |> S3.upload(storage.bucket, storage_path)
    # |> ExAws.request(Packages.render_metadata_storage(metadata))
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

      Packages.transition_deployment_with(deployment, actor, "process")
    else
      comment = "Upload partially failed"
      Logger.error("#{@logger_prefix} #{comment} - #{identifier}")

      Packages.transition_deployment_with(deployment, actor, "fail",
        comment: comment
      )
    end
  end
end
