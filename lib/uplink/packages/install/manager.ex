defmodule Uplink.Packages.Install.Manager do
  alias Uplink.{
    Packages,
    Repo
  }

  alias Packages.{
    Deployment,
    Install
  }

  alias Install.Event

  @spec create(%Deployment{}, integer | binary) ::
          {:ok, %Install{}} | {:error, Ecto.Changeset.t()}
  def create(%Deployment{id: deployment_id}, instellar_installation_id) do
    %Install{deployment_id: deployment_id}
    |> Install.changeset(%{
      instellar_installation_id: instellar_installation_id
    })
    |> Repo.insert()
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
end
