defmodule Uplink.Packages.Instance.PlacementTest do
  use ExUnit.Case

  alias Uplink.Packages.Instance.Placement

  test "name" do
    assert Placement.name("instellar-0e43123-01") == "instellar-0e43123"
  end
end
