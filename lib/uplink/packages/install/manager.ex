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
    only: [where: 3, order_by: 2, limit: 1]

  @spec create(%Deployment{}, integer | binary) ::
          {:ok, %Install{}} | {:error, Ecto.Changeset.t()}
  def create(%Deployment{id: deployment_id}, instellar_installation_id) do
    %Install{deployment_id: deployment_id}
    |> Install.changeset(%{
      instellar_installation_id: instellar_installation_id
    })
    |> Repo.insert()
  end

  def latest(instellar_install_id) do
    Packages.Install
    |> where(
      [i],
      i.instellar_installation_id == ^instellar_installation_id
    )
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec build_state(%Install{}, %Actor{}) :: map()
  def build_state(%Install{deployment: deployment} = install, actor) do
    signature = compute_signature(deployment.hash)

    {:deployment, signature, install.instellar_installation_id}
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
    |> Event.handle(actor, %{
      domain: "transitions",
      name: event_name,
      comment: comment
    })
  end

  defp fetch_deployment_metadata(%Install{deployment: deployment} = install) do
    with {:ok, metadata_params} <- Instellar.deployment_metadata(deployment),
         {:ok, %Metadata{} = metadata} <-
           Packages.parse_metadata(metadata_params) do
      signature = compute_signature(deployment.hash)

      Cache.put(
        {:deployment, signature, install.instellar_installation_id},
        metadata
      )

      %{metadata: metadata}
    end
  end
end
