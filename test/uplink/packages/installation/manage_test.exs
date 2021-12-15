defmodule Uplink.Packages.Installation.ManageTest do
  use ExUnit.Case

  alias Uplink.Packages.Installation

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uplink.Repo)

    :ok
  end

  describe "get_or_create" do
    alias Installation.Manager

    test "return installation" do
      assert %Installation{} = Manager.get_or_create(1)
    end
  end
end
