defmodule Uplink.Packages.Install.Triggers do
  use Eventful.Trigger

  alias Uplink.{
    Packages
  }

  alias Packages.{
    Install
  }

  alias Install.Execute

  Install
  |> trigger([currently: "executing"], fn event, install ->
    %{install_id: install.id, actor_id: event.actor_id}
    |> Execute.new()
    |> Oban.insert()
  end)
end
