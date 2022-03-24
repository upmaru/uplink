defmodule Uplink.Packages.Install.Triggers do
  use Eventful.Trigger

  alias Uplink.{
    Packages
  }

  alias Packages.{
    Install
  }

  alias Install.Validate

  Install
  |> trigger([currently: "validating"], fn event, install ->
    %{install_id: install.id, actor_id: event.actor_id}
    |> Validate.new()
    |> Oban.insert()
  end)
end
