defmodule Uplink.Packages.Deployment.Triggers do
  use Eventful.Trigger

  alias Uplink.{
    Packages
  }

  alias Packages.Deployment
  alias Deployment.Prepare

  Deployment
  |> trigger([currently: "preparing"], fn event, deployment ->
    %{actor_id: event.actor_id, deployment_id: deployment.id}
    |> Prepare.new()
    |> Oban.insert()
  end)
end
