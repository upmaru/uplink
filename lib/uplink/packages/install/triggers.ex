defmodule Uplink.Packages.Install.Triggers do
  use Eventful.Trigger

  alias Uplink.{
    Packages
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
    %{install_id: install.id, actor_id: event.actor_id}\
    |> Refresh.new()
    |> Oban.insert()
  end)
end
