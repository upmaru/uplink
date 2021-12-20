defmodule Uplink.Packages.Deploy do
  use Oban.Worker, queue: :deploy, max_attempts: 1

  require Logger

  alias ExAws.S3

  alias Uplink.{
    Packages,
    Cache,
    Repo
  }

  alias Packages.Deployment

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"deployment_id" => deployment_id}}) do
    deployment = Repo.get(Deployment, deployment_id)
    %Metadata{} = metadata = retrieve_metadata(deployment)
  end

  def retrieve_metadata(%Deployment{hash: hash}) do
    key_signature = compute_signature(deployment.hash)

    Cache.get({:deployment, key_signature})
    |> case do
      %Metadata{} = metadata ->
        metadata

      nil ->
        nil
        # retrieve metadata dynamically
    end
  end
end
