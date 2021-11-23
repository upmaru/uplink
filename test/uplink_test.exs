defmodule UplinkTest do
  use ExUnit.Case
  doctest Uplink

  test "greets the world" do
    assert Uplink.hello() == :world
  end
end
