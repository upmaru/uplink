defmodule Uplink.Packages.Instance.UpgradeTest do
  use ExUnit.Case
  use Oban.Testing, repo: Uplink.Repo

  import Uplink.Scenarios.Deployment

  setup [:setup_endpoints, :setup_base]

  describe "upgrade instance" do
    alias Uplink.Packages.Instance.Upgrade
  end
end
