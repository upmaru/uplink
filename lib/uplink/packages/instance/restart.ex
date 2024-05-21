defmodule Uplink.Packages.Instance.Restart do
  use Oban.Worker, queue: :instance, max_attempts: 3

  alias Uplink.Members.Actor
  alias Uplink.Packages.Install

  @transition_parameters %{
    "from" => "uplink",
    "trigger" => false
  }

  def perform(%Job{
        args:
          %{
            "instance" => %{"slug" => name},
            "install_id" => install_id,
            "actor_id" => actor_id
          } = args
      }) do
    %Actor{} = actor = Repo.get(Actor, actor_id)

    client = LXD.client()

    %Install{} =
      install =
      Install
      |> Repo.get(install_id)
      |> Repo.preload([:deployment])

    %{metadata: metadata} = Packages.build_install_state(install, actor)

    project_name = Packages.get_project_name(client, metadata)

    with {:ok, _} <- Formation.lxd_stop(client, name, project: project_name),
         %Tesla.Client{} <-
           Formation.lxd_start(client, name, project: project_name) do
    end
  end
end
