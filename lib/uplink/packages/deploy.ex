defmodule Uplink.Packages.Deploy do
  use Oban.Worker, queue: :deploy, max_attempts: 1

  require Logger

  alias ExAws.S3

  alias Uplink.{
    Packages,
    Cache,
    Repo
  }

  alias Packages.{
    Deployment,
    Metadata
  }

  alias Uplink.Clients.Instellar

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"deployment_id" => deployment_id}}) do
    %Deployment{} = deployment = Repo.get(Deployment, deployment_id)
    %Metadata{} = metadata = retrieve_metadata(deployment)
  end

  defp retrieve_metadata(%Deployment{hash: hash} = deployment) do
    key_signature = compute_signature(deployment.hash)

    Cache.get({:deployment, key_signature})
    |> case do
      %Metadata{} = metadata ->
        Map.merge(deployment, %{metadata: metadata})

      nil ->
        Instellar.deployment_metadata(deployment)
        # retrieve metadata dynamically
    end
  end

  defp execute(%Deployment{hash: hash, metadata: metadata} = deployment) do
    identifier = Deployment.identifier(deployment)
  end

  defp decompress_archive(
         path,
         extraction_path,
         {deployment, user, identifier} = state
       ) do
    Logger.info("[Uplink.Packages.Deploy] Unzipping archive - #{identifier}")

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
        Logger.error("[Uplink.Packages.Deploy] #{comment} - #{identifier}")

        Distributions.transition_deployment_with(deployment, user, "fail",
          comment: comment
        )
    end
  end

  defp process_extracted_file(path, {deployment, _user, identifier}) do
    path = to_string(path)

    %{bucket: bucket, config: storage_config} =
      Packages.render_metadata_storage(deployment.metadata)

    file_with_arch_name =
      path
      |> Path.split()
      |> Enum.take(-2)
      |> Path.join()

    storage_path = Path.join(identifier, file_with_arch_name)

    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, storage_path)
    |> ExAws.request(storage_config)
  end

  defp validate_and_finalize_deployment(
         results,
         paths,
         {deployment, user, identifier}
       ) do
    successful_uploads =
      Enum.filter(results, fn {result, _} -> result == :ok end)

    if Enum.count(successful_uploads) == Enum.count(paths) do
      Logger.info(
        "[Uplink.Packages.Deploy] Deployment completed - #{identifier}"
      )

      Distributions.transition_deployment_with(deployment, user, "complete")
    else
      comment = "Upload partially failed"
      Logger.error("[Uplink.Packages.Deploy] #{comment} - #{identifier}")

      Distributions.transition_deployment_with(deployment, user, "fail",
        comment: comment
      )
    end
  end
end
