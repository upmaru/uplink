defmodule Uplink.Packages.Install.Manager do
  alias Uplink.{
    Clients,
    Members,
    Packages,
    Cache,
    Repo
  }

  alias Packages.{
    Deployment,
    Install,
    Metadata
  }

  alias Clients.Instellar

  alias Members.Actor

  alias Install.Event

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  import Ecto.Query,
    only: [where: 3, order_by: 2, limit: 2]

  def cache_key(%Install{deployment: deployment} = install) do
    signature = compute_signature(deployment.hash)

    {:deployment, signature, install.instellar_installation_id}
  end

  @spec create(%Deployment{}, map()) ::
          {:ok, %Install{}} | {:error, Ecto.Changeset.t()}
  def create(%Deployment{id: deployment_id}, %{
        "installation_id" => instellar_installation_id,
        "deployment" => %{
          "metadata" => metadata_params
        }
      }) do
    %Install{deployment_id: deployment_id}
    |> Install.changeset(%{
      instellar_installation_id: instellar_installation_id,
      metadata_snapshot: metadata_params
    })
    |> Repo.insert()
  end

  def latest(instellar_installation_id, nil) do
    Packages.Install
    |> where(
      [i],
      i.instellar_installation_id == ^instellar_installation_id
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def latest(instellar_installation_id, %{"hash" => deployment_hash}) do
    Install.by_hash_and_installation(
      deployment_hash,
      instellar_installation_id
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def maybe_mark_complete(%Install{} = install, actor) do
    completed_instances = Cache.get({:install, install.id, "completed"})
    executing_instances = Cache.get({:install, install.id, "executing"})

    if Enum.count(completed_instances) == Enum.count(executing_instances) do
      Packages.transition_install_with(install, actor, "complete")
    else
      {:ok, :executing}
    end
  end

  @spec build_state(%Install{}, %Actor{} | nil) :: %{
          install: %Install{},
          metadata: %Metadata{},
          actor: %Members.Actor{}
        }
  def build_state(%Install{} = install, actor \\ nil) do
    install
    |> cache_key()
    |> Cache.get()
    |> case do
      %Metadata{} = metadata ->
        %{install: install, metadata: metadata, actor: actor}

      nil ->
        install
        |> fetch_deployment_metadata()
        |> Map.merge(%{install: install, actor: actor})
    end
  end

  def transition_with(install, actor, event_name, opts \\ []) do
    comment = Keyword.get(opts, :comment)

    install
    |> Repo.reload()
    |> Event.handle(actor, %{
      domain: "transitions",
      name: event_name,
      comment: comment
    })
  end

  defp fetch_deployment_metadata(
         %Install{metadata_snapshot: metadata_snapshot} = install
       ) do
    fallback_metadata =
      if metadata_snapshot.orchestration do
        metadata_snapshot
      else
        %{metadata_snapshot | orchestration: %Metadata.Orchestration{}}
      end

    with {:ok, metadata_params} <-
           Instellar.deployment_metadata(install),
         {:ok, %Metadata{} = metadata} <-
           Packages.parse_metadata(metadata_params),
         {:ok, install} <-
           install
           |> Install.changeset(%{metadata_snapshot: metadata_params})
           |> Repo.update() do
      install
      |> cache_key()
      |> Cache.put(metadata)

      %{metadata: metadata}
    else
      {:error, _} ->
        %{metadata: fallback_metadata}
    end
  end
end
