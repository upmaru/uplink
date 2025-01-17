defmodule Uplink.Packages.Install.Triggers do
  use Eventful.Trigger

  alias Uplink.Cache

  alias Uplink.{
    Packages,
    Clients
  }

  alias Packages.{
    Install
  }

  alias Install.{
    Validate,
    Execute
  }

  Install
  |> trigger([currently: "validating"], fn event, install ->
    %{install_id: install.id, actor_id: event.actor_id}
    |> Validate.new()
    |> Oban.insert()
  end)

  Install
  |> trigger([currently: "executing"], fn event, install ->
    %{install_id: install.id, actor_id: event.actor_id}
    |> Execute.new()
    |> Oban.insert()
  end)

  Install
  |> trigger([currently: "refreshing"], fn event, install ->
    Clients.Caddy.schedule_config_reload(install, actor_id: event.actor_id)
  end)

  Install
  |> trigger([currently: "completed"], fn event, install ->
    Cache.put({:install, install.id, "executing"}, [])

    Clients.Caddy.schedule_config_reload(install, actor_id: event.actor_id)
  end)
end
