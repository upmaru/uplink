defmodule Uplink.Packages.InstallTest do
  use ExUnit.Case

  import Uplink.Scenarios.Deployment

  alias Uplink.Repo
  alias Uplink.Packages

  import Ecto.Query, only: [where: 3]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    :ok
  end

  setup [:setup_base]

  test "install state is created by default", %{install: install} do
    installs = 
      Packages.Install.latest_by_installation_id(1)
      |> Repo.all()

    assert Enum.count(installs) == 1


    Packages.Install
    |> where([i], i.instellar_installation_id == ^install.instellar_installation_id)
    |> Repo.update_all(set: [instellar_installation_state: "inactive"])

    installs = 
      Packages.Install.latest_by_installation_id(1)
      |> Repo.all()

    assert Enum.count(installs) == 0
  end
end
